require 'test_helper'

class CacheHeadersTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(
      url: 'https://github.com/test/solar-energy',
      name: 'Solar Energy Toolkit',
      description: 'Tools for solar energy analysis',
      keywords: ['solar', 'energy'],
      repository: { 'language' => 'Python', 'owner' => 'test' },
      reviewed: true,
      category: 'test-category',
      sub_category: 'test-subcategory'
    )
  end

  test "projects index sets public cache headers" do
    get projects_path
    assert_response :success
    assert_cache_control "public"
    assert_cache_control "s-maxage=21600"
    assert_cache_control "stale-while-revalidate=21600"
  end

  test "projects show sets public cache headers" do
    get project_path(@project)
    assert_response :success
    assert_cache_control "public"
    assert_cache_control "s-maxage=21600"
  end

  test "projects search sets public cache headers" do
    get search_projects_path(q: 'solar')
    assert_response :success
    assert_cache_control "public"
    assert_cache_control "s-maxage=21600"
  end

  test "categories index sets public cache headers" do
    get categories_path
    assert_response :success
    assert_cache_control "public"
    assert_cache_control "s-maxage=21600"
  end

  test "categories show sets public cache headers" do
    get category_path('test-category')
    assert_response :success
    assert_cache_control "public"
    assert_cache_control "s-maxage=21600"
  end

  test "api projects index sets shorter cache headers" do
    get api_v1_projects_path
    assert_response :success
    assert_cache_control "public"
    assert_cache_control "s-maxage=3600"
  end

  test "api projects show sets shorter cache headers" do
    get api_v1_project_path(@project)
    assert_response :success
    assert_cache_control "public"
    assert_cache_control "s-maxage=3600"
  end

  test "projects new does not set cache headers" do
    get new_project_path
    assert_response :success
    refute_cache_control "s-maxage"
  end

  def assert_cache_control(directive)
    cc = response.headers['Cache-Control'] || ''
    assert cc.include?(directive), "Expected Cache-Control to include '#{directive}', got '#{cc}'"
  end

  def refute_cache_control(directive)
    cc = response.headers['Cache-Control'] || ''
    refute cc.include?(directive), "Expected Cache-Control to NOT include '#{directive}', got '#{cc}'"
  end
end
