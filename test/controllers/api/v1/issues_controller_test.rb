require 'test_helper'

class Api::V1::IssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test projects
    @climate_project = Project.create!(
      url: 'https://github.com/example/climate-project',
      name: 'Climate Project',
      category: 'Climate',
      repository: {
        'language' => 'Python',
        'stargazers_count' => 100,
        'host' => { 'name' => 'GitHub' }
      },
      keywords: ['climate', 'sustainability'],
      reviewed: true,
      last_synced_at: Time.now
    )

    @energy_project = Project.create!(
      url: 'https://github.com/example/energy-project',
      name: 'Energy Project',
      category: 'Energy',
      repository: {
        'language' => 'JavaScript',
        'stargazers_count' => 200,
        'host' => { 'name' => 'GitHub' }
      },
      keywords: ['energy', 'renewable'],
      reviewed: true,
      last_synced_at: Time.now
    )

    # Create issues for testing
    @climate_issue = Issue.create!(
      project: @climate_project,
      state: 'open',
      pull_request: false,
      number: 1,
      title: 'Climate Issue',
      labels: ["Good First Issue"],
      created_at: 1.day.ago,
      updated_at: 1.day.ago
    )

    @energy_issue = Issue.create!(
      project: @energy_project,
      state: 'open',
      pull_request: false,
      number: 2,
      title: 'Energy Issue',
      labels: ["Good First Issue"],
      created_at: 2.days.ago,
      updated_at: 12.hours.ago
    )
  end

  teardown do
    # Clean up Mocha stubs after each test
    Mocha::Mockery.instance.teardown
    Mocha::Mockery.instance.stubba.unstub_all

    # Optional: Clean up created records if not using transactional fixtures
    # Project.destroy_all
    # Issue.destroy_all
  end

  test 'should get index with all issues' do
    get api_v1_issues_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 2, actual_response.length
  end

  test 'should filter issues by category' do
    get api_v1_issues_path(category: 'Climate')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 1, actual_response.length
    assert_equal 'Climate Issue', actual_response[0]['title']
  end

  test 'should filter issues by language' do
    get api_v1_issues_path(language: 'JavaScript')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 1, actual_response.length
    assert_equal 'Energy Issue', actual_response[0]['title']
  end

  test 'should filter issues by keyword' do
    get api_v1_issues_path(keyword: 'renewable')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 1, actual_response.length
    assert_equal 'Energy Issue', actual_response[0]['title']
  end

  test 'should sort issues by created_at' do
    get api_v1_issues_path(sort: 'created_at', order: 'asc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 2, actual_response.length
    assert_equal 'Energy Issue', actual_response[0]['title'] # Created earlier
    assert_equal 'Climate Issue', actual_response[1]['title'] # Created later
  end

  test 'should sort issues by updated_at' do
    get api_v1_issues_path(sort: 'updated_at', order: 'desc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 2, actual_response.length
    assert_equal 'Energy Issue', actual_response[0]['title'] # Updated more recently
    assert_equal 'Climate Issue', actual_response[1]['title'] # Updated less recently
  end

  test 'should sort issues by stars' do
    get api_v1_issues_path(sort: 'stars', order: 'desc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 2, actual_response.length
    # Order based on the created @energy_project (200 stars) and @climate_project (100 stars)
    assert_equal 'Energy Issue', actual_response[0]['title'] # 200 stars
    assert_equal 'Climate Issue', actual_response[1]['title'] # 100 stars
  end

  test 'should combine filtering and sorting' do
    get api_v1_issues_path(category: 'Climate', sort: 'stars', order: 'desc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 1, actual_response.length
    assert_equal 'Climate Issue', actual_response[0]['title']
  end

  test 'should get openclimateaction projects' do
    get openclimateaction_api_v1_issues_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_not_nil actual_response
    assert_instance_of Array, actual_response
  end
end