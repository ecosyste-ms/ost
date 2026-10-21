require 'test_helper'

class MissingRepositoriesTest < ActionDispatch::IntegrationTest
  setup do
    @repository = {
      'full_name' => 'OpenSourceFellows/map-dashboard', 'owner' => 'OpenSourceFellows',
      'host' => { 'name' => 'GitHub' }, 'archived' => false, 'topics' => [],
      'last_synced_at' => 4.days.ago.iso8601, 'pushed_at' => 1.month.ago.iso8601
    }
    @project = Project.create!(url: 'https://github.com/OpenSourceFellows/map-dashboard',
      reviewed: true, repository: @repository, commits: { 'past_year_total_commits' => 10 })
    Issue.create!(project: @project, number: 1, title: 'Help with the map', state: 'open',
      pull_request: false, labels: ['good first issue'], created_at: 1.day.ago, updated_at: 1.day.ago)
    @lookup = stub_request(:get, 'https://repos.ecosyste.ms/api/v1/repositories/lookup')
      .with(query: hash_including('url' => @project.url))
    stub_request(:get, @project.url).to_return(status: 404)
    %i[fetch_owner fetch_dependencies fetch_packages fetch_commits fetch_events fetch_issue_stats
       sync_issues fetch_citation_file fetch_readme sync_releases update_committers
       update_keywords_from_contributors update_score update_science_score matching_criteria? ping].each do |method|
      Project.any_instance.stubs(method)
    end
  end

  test 'a missing repository is removed from active project responses after sync' do
    get openclimateaction_api_v1_issues_path
    assert_includes response.parsed_body.pluck('id'), @project.id
    assert @project.active?
    @lookup.to_return(status: 404, body: { error: 'Repository not found' }.to_json)

    SyncProjectWorker.new.perform(@project.id)

    assert_nil @project.reload.repository
    refute @project.active?
    assert @project.persisted?
    assert_equal 1, @project.issues.count
    get openclimateaction_api_v1_issues_path
    assert_response :success
    refute_includes response.parsed_body.pluck('id'), @project.id
    get api_v1_project_path(@project)
    assert_response :success
    assert_nil response.parsed_body['repository']
  end

  test 'a successful lookup restores a missing repository to active responses' do
    @project.update!(repository: nil)
    @lookup.to_return(status: 200, body: @repository.to_json)

    SyncProjectWorker.new.perform(@project.id)

    assert_equal @repository, @project.reload.repository
    assert @project.active?
    get openclimateaction_api_v1_issues_path
    assert_response :success
    assert_includes response.parsed_body.pluck('id'), @project.id
  end

  test 'temporary lookup failures preserve the repository snapshot' do
    [429, 500, 503].each do |status|
      @lookup.to_return(status: status)

      SyncProjectWorker.new.perform(@project.id)

      assert_equal @repository, @project.reload.repository
      assert @project.active?
    end
  end
end
