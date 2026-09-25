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

  test "index ignores sort values not in the allowlist" do
    get projects_path(sort: '(CASE WHEN (SELECT 1 FROM secrets) THEN 1 ELSE 2 END)', order: 'asc')
    assert_response :success
    sql = assigns(:scope).to_sql
    refute_includes sql, 'secrets'
    assert_includes sql, 'ORDER BY score ASC'
  end

  test "index sorts by an allowed column" do
    get projects_path(sort: 'last_synced_at', order: 'asc')
    assert_response :success
    assert_includes assigns(:scope).to_sql, 'ORDER BY last_synced_at ASC'
  end

  test "review ignores sort values not in the allowlist" do
    get review_projects_path(sort: '(SELECT 1)', order: 'desc')
    assert_response :success
    sql = assigns(:scope).to_sql
    refute_includes sql, 'SELECT 1'
    assert_includes sql, 'ORDER BY vote_count DESC'
  end

  test "packages renders successfully" do
    pkg_data = [{ 'name' => 'test-pkg', 'ecosystem' => 'pypi', 'downloads' => 1000,
                  'downloads_period' => 'last-month', 'dependent_packages_count' => 5,
                  'dependent_repos_count' => 10, 'versions_count' => 3,
                  'rankings' => { 'average' => 50 }, 'registry' => { 'name' => 'PyPI', 'url' => 'https://pypi.org' },
                  'registry_url' => 'https://pypi.org/project/test-pkg',
                  'maintainers' => [], 'advisories' => [] }]
    @project.update_column(:packages, pkg_data)

    get packages_projects_path
    assert_response :success
  end
end
