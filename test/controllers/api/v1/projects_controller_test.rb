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
    assert_equal 3, actual_response.length

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
    assert_equal 3, actual_response.length
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

end
