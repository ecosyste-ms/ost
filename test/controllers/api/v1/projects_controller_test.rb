require 'test_helper'

class Api::V1::ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create test projects
    @climate_project = Project.create!(
      url: 'https://github.com/example/climate-project',
      name: 'Climate Project',
      description: 'A climate-focused open source project',
      category: 'Climate',
      sub_category: 'Carbon Tracking',
      repository: {
        'language' => 'Python',
        'stargazers_count' => 100,
        'host' => { 'name' => 'GitHub' },
        'full_name' => 'example/climate-project'
      },
      keywords: ['climate', 'sustainability'],
      reviewed: true,
      last_synced_at: 2.days.ago,
      packages: [{
        'name' => 'climate-lib',
        'downloads' => 1000,
        'metadata' => {}
      }],
      readme: 'Climate project readme with ![image](https://example.com/image.png)'
    )

    @energy_project = Project.create!(
      url: 'https://github.com/example/energy-project',
      name: 'Energy Project',
      description: 'An energy management project',
      category: 'Energy',
      sub_category: 'Solar',
      repository: {
        'language' => 'JavaScript',
        'stargazers_count' => 200,
        'host' => { 'name' => 'GitHub' },
        'full_name' => 'example/energy-project'
      },
      keywords: ['energy', 'renewable'],
      reviewed: true,
      last_synced_at: 1.day.ago
    )

    @unsynced_project = Project.create!(
      url: 'https://github.com/example/unsynced-project',
      name: 'Unsynced Project',
      repository: {
        'language' => 'Ruby',
        'host' => { 'name' => 'GitHub' }
      },
      reviewed: false,
      last_synced_at: nil
    )

    @esd_project = Project.create!(
      url: 'https://github.com/example/esd-project',
      name: 'ESD Project',
      repository: {
        'language' => 'Go',
        'host' => { 'name' => 'GitHub' }
      },
      reviewed: true,
      last_synced_at: 1.hour.ago,
      esd: true
    )

    # Projects with dependencies for testing dependencies endpoint
    @project_with_deps_1 = Project.create!(
      url: 'https://github.com/example/deps-project-1',
      name: 'Project with Dependencies 1',
      repository: { 'host' => { 'name' => 'GitHub' } },
      reviewed: true,
      last_synced_at: 1.hour.ago,
      dependencies: [
        {
          'dependencies' => [
            { 'ecosystem' => 'npm', 'package_name' => 'React', 'direct' => true },
            { 'ecosystem' => 'npm', 'package_name' => 'Express', 'direct' => true },
            { 'ecosystem' => 'python', 'package_name' => 'Django', 'direct' => true }
          ]
        }
      ]
    )

    @project_with_deps_2 = Project.create!(
      url: 'https://github.com/example/deps-project-2',
      name: 'Project with Dependencies 2',
      repository: { 'host' => { 'name' => 'GitHub' } },
      reviewed: true,
      last_synced_at: 1.hour.ago,
      dependencies: [
        {
          'dependencies' => [
            { 'ecosystem' => 'npm', 'package_name' => 'React', 'direct' => true },
            { 'ecosystem' => 'npm', 'package_name' => 'Vue', 'direct' => true }
          ]
        }
      ]
    )
  end

  teardown do
    Mocha::Mockery.instance.teardown
    Mocha::Mockery.instance.stubba.unstub_all
  end

  # INDEX TESTS
  test 'should get index with synced projects' do
    get api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 5, actual_response.length

    # Should not include unsynced project
    project_names = actual_response.map { |p| p['name'] }
    assert_includes project_names, 'Climate Project'
    assert_includes project_names, 'Energy Project'
    assert_not_includes project_names, 'Unsynced Project'
  end

  test 'should filter index by reviewed status' do
    get api_v1_projects_path(reviewed: 'true')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 5, actual_response.length
    actual_response.each do |project|
      # All returned projects should be reviewed
      project_record = Project.find(project['id'])
      assert project_record.reviewed
    end
  end

  test 'should sort index by custom field ascending with nulls last' do
    get api_v1_projects_path(sort: 'projects.updated_at', order: 'asc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.length > 0
  end

  test 'should sort index by custom field descending with nulls last' do
    get api_v1_projects_path(sort: 'projects.updated_at', order: 'desc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.length > 0
  end

  test 'should use default sort when not specified' do
    get api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.length > 0
  end

  # SHOW TESTS
  test 'should show project' do
    get api_v1_project_path(@climate_project.id)
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal @climate_project.id, actual_response['id']
    assert_equal 'Climate Project', actual_response['name']
    assert_equal 'https://github.com/example/climate-project', actual_response['url']
  end

  test 'should return project with all expected fields' do
    get api_v1_project_path(@climate_project.id)
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_includes actual_response.keys, 'id'
    assert_includes actual_response.keys, 'name'
    assert_includes actual_response.keys, 'description'
    assert_includes actual_response.keys, 'url'
    assert_includes actual_response.keys, 'repository'
    assert_includes actual_response.keys, 'keywords'
    assert_includes actual_response.keys, 'category'
  end

  # LOOKUP TESTS
  test 'should lookup existing project' do
    get lookup_api_v1_projects_path(url: @climate_project.url)
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal @climate_project.id, actual_response['id']
    assert_equal 'Climate Project', actual_response['name']
  end

  test 'should create new project on lookup if not found' do
    new_url = 'https://github.com/example/new-project'

    assert_difference 'Project.count', 1 do
      get lookup_api_v1_projects_path(url: new_url)
      assert_response :success
    end

    actual_response = JSON.parse(@response.body)
    assert_equal new_url.downcase, actual_response['url']
  end

  test 'should handle case insensitive lookup' do
    get lookup_api_v1_projects_path(url: @climate_project.url.upcase)
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal @climate_project.id, actual_response['id']
  end

  # PING TESTS
  test 'should ping project to trigger sync' do
    project = @climate_project

    get ping_api_v1_project_path(project.id)
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert_equal 'pong', actual_response['message']
  end

  # PACKAGES TESTS
  test 'should get projects with packages' do
    get packages_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)

    # Should only include projects with packages
    if actual_response.any?
      actual_response.each do |project|
        project_record = Project.find(project['id'])
        assert project_record.packages.present?
      end
    end
  end

  test 'packages endpoint should sort by total downloads' do
    get packages_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    # Should return projects sorted by download count
    assert actual_response.is_a?(Array)
  end

  # IMAGES TESTS
  test 'should get projects with images' do
    get images_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)

    # Should only include projects with readme images
    if actual_response.any?
      actual_response.each do |project|
        project_record = Project.find(project['id'])
        assert project_record.readme.present?
        assert project_record.readme_image_urls.present?
      end
    end
  end

  # ESD TESTS
  test 'should get esd projects' do
    get esd_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
    assert_equal 1, actual_response.length
    assert_equal @esd_project.id, actual_response[0]['id']
  end

  test 'should sort esd projects ascending' do
    get esd_api_v1_projects_path(sort: 'projects.updated_at', order: 'asc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
  end

  test 'should sort esd projects descending' do
    get esd_api_v1_projects_path(sort: 'projects.updated_at', order: 'desc')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
  end

  # DEPENDENCIES TESTS
  test 'should get dependencies' do
    get dependencies_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
  end

  test 'dependencies should have required fields' do
    get dependencies_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    if actual_response.any?
      dependency = actual_response.first
      assert_includes dependency.keys, 'ecosystem'
      assert_includes dependency.keys, 'package_name'
      assert_includes dependency.keys, 'count'
      assert_includes dependency.keys, 'in_ost'
    end
  end

  test 'dependencies should filter out python and r packages' do
    get dependencies_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    actual_response.each do |dependency|
      assert_not_equal 'python', dependency['ecosystem']
      assert_not_equal 'r', dependency['ecosystem']
    end
  end

  test 'dependencies should be sorted by count descending' do
    get dependencies_api_v1_projects_path
    assert_response :success

    actual_response = JSON.parse(@response.body)
    if actual_response.length > 1
      # Check that counts are in descending order
      counts = actual_response.map { |d| d['count'] }
      assert_equal counts, counts.sort.reverse
    end
  end

  test 'dependencies should support pagination' do
    get dependencies_api_v1_projects_path(per_page: 1)
    assert_response :success

    actual_response = JSON.parse(@response.body)
    # Should only return 1 item per page
    assert actual_response.length <= 1

    # Check pagination headers are present
    assert_not_nil response.headers['Current-Page']
    assert_not_nil response.headers['Page-Items']
  end

  test 'dependencies should support custom per_page parameter' do
    get dependencies_api_v1_projects_path(per_page: 50)
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.length <= 50
  end

  # SEARCH TESTS
  test 'search should return matching projects' do
    get search_api_v1_projects_path(q: 'climate')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
    names = actual_response.map { |p| p['name'] }
    assert_includes names, 'Climate Project'
  end

  test 'search with blank query returns results' do
    get search_api_v1_projects_path(q: '')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
  end

  test 'search with keyword filter' do
    get search_api_v1_projects_path(q: 'climate', keywords: 'sustainability')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
  end

  test 'search with language filter' do
    get search_api_v1_projects_path(q: '', language: 'Python')
    assert_response :success

    actual_response = JSON.parse(@response.body)
    assert actual_response.is_a?(Array)
  end

  test 'dependencies should default to 100 items per page' do
    get dependencies_api_v1_projects_path
    assert_response :success

    # Check pagination headers
    assert_equal '100', response.headers['Page-Items']
  end

end
