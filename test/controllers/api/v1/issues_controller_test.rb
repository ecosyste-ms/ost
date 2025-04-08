require 'test_helper'

class Api::V1::IssuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a project with specific attributes for filtering tests
    @climate_project = Project.create!(
      url: 'https://github.com/example/climate-project',
      name: 'Climate Project',
      category: 'Climate',
      repository: {
        'language' => 'Python',
        'stargazers_count' => 100,
        'host' => { 'name' => 'GitHub' },
        'archived' => false
      },
      keywords: ['climate', 'sustainability'],
      reviewed: true
    )
    
    @energy_project = Project.create!(
      url: 'https://github.com/example/energy-project',
      name: 'Energy Project',
      category: 'Energy',
      repository: {
        'language' => 'JavaScript',
        'stargazers_count' => 200,
        'host' => { 'name' => 'GitHub' },
        'archived' => false
      },
      keywords: ['energy', 'renewable'],
      reviewed: true
    )
    
    # Create issues for the projects
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
  
  test 'should get index with all issues' do
    get api_v1_issues_path
    assert_response :success
    
    # Parse response body
    json_response = JSON.parse(@response.body)
    
    # Verify we get both issues
    assert_equal 2, json_response.length
  end
  
  test 'should filter issues by category' do
    get api_v1_issues_path(category: 'Climate')
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    # Should only return the climate issue
    assert_equal 1, json_response.length
    assert_equal 'Climate Issue', json_response[0]['title']
  end
  
  test 'should filter issues by language' do
    get api_v1_issues_path(language: 'JavaScript')
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    # Should only return the energy issue (JavaScript)
    assert_equal 1, json_response.length
    assert_equal 'Energy Issue', json_response[0]['title']
  end
  
  test 'should filter issues by keyword' do
    get api_v1_issues_path(keyword: 'renewable')
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    # Should only return the energy issue
    assert_equal 1, json_response.length
    assert_equal 'Energy Issue', json_response[0]['title']
  end
  
  test 'should sort issues by created_at' do
    get api_v1_issues_path(sort: 'created_at', order: 'asc')
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    # Should return issues sorted by created_at in ascending order
    assert_equal 2, json_response.length
    assert_equal 'Energy Issue', json_response[0]['title'] # Created earlier
    assert_equal 'Climate Issue', json_response[1]['title'] # Created later
  end
  
  test 'should sort issues by updated_at' do
    get api_v1_issues_path(sort: 'updated_at', order: 'desc')
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    # Should return issues sorted by updated_at in descending order
    assert_equal 2, json_response.length
    assert_equal 'Energy Issue', json_response[0]['title'] # Updated more recently
    assert_equal 'Climate Issue', json_response[1]['title'] # Updated less recently
  end
  
  test 'should sort issues by stars' do
    get api_v1_issues_path(sort: 'stars', order: 'desc')
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    # Should return issues sorted by project stars in descending order
    assert_equal 2, json_response.length
    assert_equal 'Energy Issue', json_response[0]['title'] # 200 stars
    assert_equal 'Climate Issue', json_response[1]['title'] # 100 stars
  end
  
  test 'should combine filtering and sorting' do
    get api_v1_issues_path(category: 'Climate', sort: 'stars', order: 'desc')
    assert_response :success
    
    json_response = JSON.parse(@response.body)
    
    # Should only return the climate issue
    assert_equal 1, json_response.length
    assert_equal 'Climate Issue', json_response[0]['title']
  end
  
  test 'should get openclimateaction projects' do
    get openclimateaction_api_v1_issues_path
    assert_response :success
    
    # This test just verifies the endpoint works
    # We're not testing the details since we didn't modify this endpoint
    json_response = JSON.parse(@response.body)
    assert json_response.is_a?(Array)
  end
end