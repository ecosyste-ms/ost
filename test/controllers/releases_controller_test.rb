require 'test_helper'

class ReleasesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(
      url: 'https://github.com/test/solar-energy',
      name: 'Solar Energy Toolkit',
      repository: { 'language' => 'Python', 'owner' => 'test' },
      reviewed: true
    )
    @release = @project.releases.create!(
      uuid: 'abc123',
      tag_name: 'v1.0.0',
      name: 'v1.0.0',
      body: 'First release',
      published_at: Time.now,
      html_url: 'https://github.com/test/solar-energy/releases/tag/v1.0.0'
    )
  end

  test "index renders releases" do
    get releases_path
    assert_response :success
    assert_includes assigns(:releases), @release
  end

  test "index returns 404 when page overflows" do
    get releases_path(page: 999)
    assert_response :not_found
  end

  test "index scoped to project returns 404 when page overflows" do
    get project_releases_path(@project, page: 999)
    assert_response :not_found
  end
end
