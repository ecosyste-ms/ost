require 'test_helper'

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(
      url: 'https://github.com/test/solar-energy',
      name: 'Solar Energy Toolkit',
      description: 'Tools for solar energy analysis',
      keywords: ['solar', 'energy', 'renewables'],
      repository: { 'language' => 'Python', 'owner' => 'test' },
      reviewed: true
    )

    @other_project = Project.create!(
      url: 'https://github.com/test/wind-power',
      name: 'Wind Power Model',
      description: 'Wind turbine simulation',
      keywords: ['wind', 'energy'],
      repository: { 'language' => 'Julia', 'owner' => 'test' },
      reviewed: true
    )
  end

  test "search with query returns matching results" do
    get search_projects_path(q: 'solar')
    assert_response :success
    assert_select '.col-md-9' # results column exists
  end

  test "search with blank query returns all reviewed" do
    get search_projects_path(q: '')
    assert_response :success
  end

  test "search with keyword filter" do
    get search_projects_path(q: 'energy', keywords: 'solar')
    assert_response :success
  end

  test "search with language filter" do
    get search_projects_path(q: 'energy', language: 'Python')
    assert_response :success
  end

  test "search assigns facets" do
    get search_projects_path(q: 'energy')
    assert_response :success
    assert assigns(:facets).key?("keywords")
    assert assigns(:facets).key?("language")
  end

  test "search paginates results" do
    get search_projects_path(q: 'energy')
    assert_response :success
    assert_not_nil assigns(:pagy)
  end
end
