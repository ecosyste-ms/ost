require 'test_helper'

class ProjectRepositoryRefreshTest < ActiveSupport::TestCase
  setup do
    travel_to Time.current.change(usec: 0)
    Sidekiq::Worker.clear_all
    Rails.logger.stubs(:warn)
    @old_api_key = ENV['ECOSYSTEMS_API_KEY']
    ENV['ECOSYSTEMS_API_KEY'] = 'test-refresh-key'
    @repository = {
      'full_name' => 'RWTH-EBC/TEASER', 'owner' => 'RWTH-EBC',
      'host' => { 'name' => 'GitHub' }, 'last_synced_at' => 4.days.ago.iso8601,
      'pushed_at' => 2.months.ago.iso8601, 'topics' => []
    }
    @project = Project.create!(url: 'https://github.com/RWTH-EBC/TEASER', repository: @repository)
    @lookup_url = 'https://repos.ecosyste.ms/api/v1/repositories/lookup'
    @ping_url = 'https://repos.ecosyste.ms/api/v1/hosts/GitHub/repositories/RWTH-EBC/TEASER/ping'
    @headers = { 'X-API-Key' => 'test-refresh-key', 'User-Agent' => 'ost.ecosyste.ms' }
    stub_request(:get, @project.url).to_return(status: 200)
    stub_request(:get, %r{https://(issues|commits)\.ecosyste\.ms/.*?/ping}).to_return(status: 200)
    stub_request(:get, 'https://repos.ecosyste.ms/api/v1/hosts/GitHub/owners/RWTH-EBC/ping').to_return(status: 200)
    %i[fetch_owner fetch_dependencies fetch_packages combine_keywords fetch_commits fetch_events
       fetch_issue_stats update_committers update_keywords_from_contributors update_score
       update_science_score matching_criteria?].each do |method|
      Project.any_instance.stubs(method)
    end
  end

  teardown do
    ENV['ECOSYSTEMS_API_KEY'] = @old_api_key
    travel_back
  end

  test 'sync requests a forced refresh of stale data and reads it back on the next sync' do
    queries = []
    fresh = @repository.merge('last_synced_at' => Time.current.iso8601, 'pushed_at' => 1.hour.ago.iso8601)
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url), headers: @headers)
      .to_return do |request|
        queries << request.uri.query_values
        { status: 200, body: (queries.length == 1 ? @repository : fresh).to_json }
      end
    forced_ping = stub_request(:post, @ping_url).with(query: { 'force' => 'true' }, headers: @headers).to_return(status: 200)
    normal_ping = stub_request(:post, @ping_url).with(headers: @headers).to_return(status: 200)

    SyncProjectWorker.new.perform(@project.id)
    assert_equal @repository['pushed_at'], @project.reload.repository['pushed_at']
    assert_requested forced_ping, times: 1

    travel 1.hour
    SyncProjectWorker.new.perform(@project.id)
    assert_equal fresh['pushed_at'], @project.reload.repository['pushed_at']
    assert_requested normal_ping, times: 1
    assert queries.all? { |query| query['_refresh'].present? }
    assert_equal 2, queries.map { |query| query['_refresh'] }.uniq.length
  end

  test 'forced refresh is read back an hour later without waiting for the next sync' do
    queries = []
    fresh = @repository.merge('last_synced_at' => 10.minutes.from_now.iso8601, 'pushed_at' => 1.hour.ago.iso8601)
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return do |request|
        queries << request.uri.query_values
        { status: 200, body: (queries.length == 1 ? @repository : fresh).to_json }
      end
    stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 200)

    SyncProjectWorker.new.perform(@project.id)
    job = RefreshRepositoryWorker.jobs.sole
    assert_equal [@project.id], job['args']
    assert_in_delta 1.hour.from_now.to_f, job['at'], 1

    travel 1.hour
    RefreshRepositoryWorker.drain
    assert_equal fresh['pushed_at'], @project.reload.repository['pushed_at']
    assert_equal 2, queries.map { |query| query['_refresh'] }.uniq.length
  end

  test 'read-back retries hourly until repos has refreshed' do
    queries = []
    fresh = @repository.merge('last_synced_at' => (3.hours.from_now - 10.minutes).iso8601, 'pushed_at' => 1.hour.ago.iso8601)
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return do |request|
        queries << request.uri.query_values
        { status: 200, body: (queries.length < 4 ? @repository : fresh).to_json }
      end
    stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 200)

    SyncProjectWorker.new.perform(@project.id)
    2.times do |i|
      travel 1.hour
      RefreshRepositoryWorker.perform_one
      assert_equal [@project.id, i + 2], RefreshRepositoryWorker.jobs.sole['args']
    end

    travel 1.hour
    RefreshRepositoryWorker.perform_one
    assert_empty RefreshRepositoryWorker.jobs
    assert_equal fresh['pushed_at'], @project.reload.repository['pushed_at']
    assert_equal 4, queries.map { |query| query['_refresh'] }.uniq.length
  end

  test 'read-back stops retrying after the last attempt' do
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)

    RefreshRepositoryWorker.new.perform(@project.id, RefreshRepositoryWorker::MAX_ATTEMPTS - 1)
    assert_equal [@project.id, RefreshRepositoryWorker::MAX_ATTEMPTS], RefreshRepositoryWorker.jobs.sole['args']

    RefreshRepositoryWorker.clear
    RefreshRepositoryWorker.new.perform(@project.id, RefreshRepositoryWorker::MAX_ATTEMPTS)
    assert_empty RefreshRepositoryWorker.jobs
  end

  test 'read-back does not retry a repository repos no longer has' do
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url)).to_return(status: 404)

    RefreshRepositoryWorker.new.perform(@project.id)

    assert_nil @project.reload.repository
    assert_empty RefreshRepositoryWorker.jobs
  end

  test 'a read-back snapshot is still force refreshed at the next daily sync' do
    @repository['last_synced_at'] = 23.hours.ago.iso8601
    @project.update!(repository: @repository)
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)
    forced_ping = stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 200)

    SyncProjectWorker.new.perform(@project.id)

    assert_requested forced_ping
  end

  test 'unforced and failed pings do not schedule a read-back' do
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)
    stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 503)

    SyncProjectWorker.new.perform(@project.id)

    @repository['last_synced_at'] = 1.hour.ago.iso8601
    @project.update!(repository: @repository)
    stub_request(:post, @ping_url).to_return(status: 200)
    SyncProjectWorker.new.perform(@project.id)

    assert_empty RefreshRepositoryWorker.jobs
  end

  test 'sync of a recent snapshot keeps the cached lookup and does not force refresh' do
    @repository['last_synced_at'] = 1.hour.ago.iso8601
    @project.update!(repository: @repository)
    lookup = stub_request(:get, @lookup_url).with(query: { 'url' => @project.url }, headers: @headers)
      .to_return(status: 200, body: @repository.to_json)
    ping = stub_request(:post, @ping_url).with(headers: @headers).to_return(status: 200)

    SyncProjectWorker.new.perform(@project.id)

    assert_requested lookup
    assert_requested ping
  end

  test 'sync requests a refresh when repository freshness is unknown' do
    @repository.delete('last_synced_at')
    @project.update!(repository: @repository)
    lookup = stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)
    ping = stub_request(:post, @ping_url).with(query: { 'force' => 'true' }, headers: @headers).to_return(status: 200)

    SyncProjectWorker.new.perform(@project.id)

    assert_requested lookup
    assert_requested ping
  end

  test 'failed refresh acknowledgement is logged' do
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)
    stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 503)
    Rails.logger.expects(:warn).with("Ping failed for #{@ping_url}: HTTP 503")

    SyncProjectWorker.new.perform(@project.id)
  end

  test 'stale lookups share a cache key within the hour' do
    queries = []
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return do |request|
        queries << request.uri.query_values
        { status: 200, body: @repository.to_json }
      end
    stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 200)

    2.times { SyncProjectWorker.new.perform(@project.id) }

    assert_equal [Time.current.beginning_of_hour.to_i.to_s] * 2, queries.map { |query| query['_refresh'] }
  end

  test 'invalid repository timestamps request a refresh' do
    @repository['last_synced_at'] = 'invalid'
    @project.update!(repository: @repository)
    lookup = stub_request(:get, @lookup_url).with(query: {
      'url' => @project.url, '_refresh' => Time.current.beginning_of_hour.to_i.to_s
    }).to_return(status: 200, body: @repository.to_json)
    ping = stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 200)

    SyncProjectWorker.new.perform(@project.id)

    assert_requested lookup
    assert_requested ping
  end

  test 'a timed out repository ping does not stop later pings' do
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)
    ping = stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_timeout
    Rails.logger.expects(:warn).with("Ping failed for #{@ping_url}: Faraday::TimeoutError").once

    SyncProjectWorker.new.perform(@project.id)

    assert_requested ping, times: 1
    assert_requested :get, @project.owner_ping_url, times: 1
  end

  test 'a timed out GET ping is not retried and does not stop later pings' do
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)
    stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 200)
    ping = stub_request(:get, @project.issues_ping_url).to_timeout
    Rails.logger.expects(:warn).with("Ping failed for #{@project.issues_ping_url}: Faraday::TimeoutError").once

    SyncProjectWorker.new.perform(@project.id)

    assert_requested ping, times: 1
    assert_requested :get, @project.owner_ping_url, times: 1
  end

  test 'a malformed package ping URL does not fail the sync or stop later pings' do
    @project.update!(packages: [{ 'registry' => { 'name' => 'npm' }, 'name' => 'bad name' }])
    stub_request(:get, @lookup_url).with(query: hash_including('url' => @project.url))
      .to_return(status: 200, body: @repository.to_json)
    stub_request(:post, @ping_url).with(query: { 'force' => 'true' }).to_return(status: 200)
    Rails.logger.expects(:warn).with("Ping failed for #{@project.packages_ping_urls.sole}: URI::InvalidURIError").once

    SyncProjectWorker.new.perform(@project.id)

    assert_requested :get, @project.owner_ping_url, times: 1
    assert_equal Time.current, @project.reload.last_synced_at
  end
end
