require 'test_helper'

class ProjectIssueSyncTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(url: 'https://github.com/LandSciTech/bbousuite', reviewed: true)
    @repository_url = 'https://issues.ecosyste.ms/api/v1/hosts/GitHub/repositories/LandSciTech%2Fbbousuite'
    @issues_url = "#{@repository_url}/issues"
    @pending = { status: 'pending', repository_url: @repository_url, issues_url: @issues_url }
    @issue = {
      number: 12, title: 'Example issue', state: 'open', pull_request: false,
      created_at: '2026-10-20T10:00:00Z', updated_at: '2026-10-21T11:00:00Z'
    }
    %i[check_url fetch_repository fetch_owner fetch_dependencies fetch_packages combine_keywords
       fetch_commits fetch_events fetch_issue_stats fetch_citation_file fetch_readme sync_releases
       update_committers update_keywords_from_contributors matching_criteria? update_score
       update_science_score ping].each do |method|
      Project.any_instance.stubs(method)
    end
  end

  test 'worker defers a pending repository lookup and imports issues on the next sync' do
    stub_request(:get, @project.issues_api_url).to_return(
      { status: 202, body: @pending.to_json },
      { status: 200, body: { issues_url: @issues_url }.to_json }
    )
    issues_request = stub_request(:get, @issues_url).with(query: { per_page: '1000', pull_request: 'false' })
      .to_return(status: 200, body: [@issue].to_json)

    assert_no_difference 'Issue.count' do
      SyncProjectWorker.new.perform(@project.id)
    end
    assert_not_requested issues_request
    assert_not_nil @project.reload.last_synced_at

    assert_difference 'Issue.count', 1 do
      SyncProjectWorker.new.perform(@project.id)
    end
    assert_equal 'Example issue', @project.issues.find_by!(number: 12).title
  end

  test 'worker preserves existing issues when the issue list is pending' do
    existing = @project.issues.create!(@issue)
    stub_request(:get, @project.issues_api_url)
      .to_return(status: 200, body: { issues_url: @issues_url }.to_json)
    stub_request(:get, @issues_url).with(query: { per_page: '1000', pull_request: 'false' })
      .to_return(status: 202, body: @pending.to_json)

    assert_no_difference 'Issue.count' do
      SyncProjectWorker.new.perform(@project.id)
    end

    assert_equal 'Example issue', existing.reload.title
    assert_not_nil @project.reload.last_synced_at
  end

  test 'worker updates an existing issue and preserves upstream timestamps' do
    existing = @project.issues.create!(@issue.merge(title: 'Old title'))
    stub_request(:get, @project.issues_api_url)
      .to_return(status: 200, body: { issues_url: @issues_url }.to_json)
    stub_request(:get, @issues_url).with(query: { per_page: '1000', pull_request: 'false' })
      .to_return(status: 200, body: [@issue].to_json)

    assert_no_difference 'Issue.count' do
      SyncProjectWorker.new.perform(@project.id)
    end

    assert_equal 'Example issue', existing.reload.title
    assert_equal Time.iso8601(@issue[:created_at]), existing.created_at
    assert_equal Time.iso8601(@issue[:updated_at]), existing.updated_at
  end

  test 'worker accepts a synced repository with no issues' do
    stub_request(:get, @project.issues_api_url)
      .to_return(status: 200, body: { issues_url: @issues_url }.to_json)
    stub_request(:get, @issues_url).with(query: { per_page: '1000', pull_request: 'false' })
      .to_return(status: 200, body: '[]')

    assert_no_difference 'Issue.count' do
      SyncProjectWorker.new.perform(@project.id)
    end

    assert_not_nil @project.reload.last_synced_at
  end
end
