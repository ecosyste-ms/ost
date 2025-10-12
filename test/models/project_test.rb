require 'test_helper'

class ProjectTest < ActiveSupport::TestCase
  test "github_pages_to_repo_url" do
    project = Project.new
    repo_url = project.github_pages_to_repo_url('https://foo.github.io/bar')
    assert_equal 'https://github.com/foo/bar', repo_url
  end

  test "github_pages_to_repo_url with trailing slash" do
    project = Project.new(url: 'https://foo.github.io/bar/')
    repo_url = project.repository_url
    assert_equal 'https://github.com/foo/bar', repo_url
  end

  test "total_dependent_repos with no packages" do
    project = Project.new(packages: nil)
    assert_equal 0, project.total_dependent_repos
  end

  test "total_dependent_repos with empty packages array" do
    project = Project.new(packages: [])
    assert_equal 0, project.total_dependent_repos
  end

  test "total_dependent_repos with single package" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_repos_count' => 100 }
    ])
    assert_equal 100, project.total_dependent_repos
  end

  test "total_dependent_repos with multiple packages" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_repos_count' => 100 },
      { 'name' => 'pkg2', 'dependent_repos_count' => 250 },
      { 'name' => 'pkg3', 'dependent_repos_count' => 50 }
    ])
    assert_equal 400, project.total_dependent_repos
  end

  test "total_dependent_repos with missing dependent_repos_count" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_repos_count' => 100 },
      { 'name' => 'pkg2' },
      { 'name' => 'pkg3', 'dependent_repos_count' => 50 }
    ])
    assert_equal 150, project.total_dependent_repos
  end

  test "total_dependent_repos with nil dependent_repos_count" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_repos_count' => 100 },
      { 'name' => 'pkg2', 'dependent_repos_count' => nil },
      { 'name' => 'pkg3', 'dependent_repos_count' => 50 }
    ])
    assert_equal 150, project.total_dependent_repos
  end

  test "total_dependent_packages with no packages" do
    project = Project.new(packages: nil)
    assert_equal 0, project.total_dependent_packages
  end

  test "total_dependent_packages with empty packages array" do
    project = Project.new(packages: [])
    assert_equal 0, project.total_dependent_packages
  end

  test "total_dependent_packages with single package" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_packages_count' => 500 }
    ])
    assert_equal 500, project.total_dependent_packages
  end

  test "total_dependent_packages with multiple packages" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_packages_count' => 500 },
      { 'name' => 'pkg2', 'dependent_packages_count' => 1200 },
      { 'name' => 'pkg3', 'dependent_packages_count' => 300 }
    ])
    assert_equal 2000, project.total_dependent_packages
  end

  test "total_dependent_packages with missing dependent_packages_count" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_packages_count' => 500 },
      { 'name' => 'pkg2' },
      { 'name' => 'pkg3', 'dependent_packages_count' => 300 }
    ])
    assert_equal 800, project.total_dependent_packages
  end

  test "total_dependent_packages with nil dependent_packages_count" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_packages_count' => 500 },
      { 'name' => 'pkg2', 'dependent_packages_count' => nil },
      { 'name' => 'pkg3', 'dependent_packages_count' => 300 }
    ])
    assert_equal 800, project.total_dependent_packages
  end

  test "total_dependent_repos and total_dependent_packages with zero values" do
    project = Project.new(packages: [
      { 'name' => 'pkg1', 'dependent_repos_count' => 0, 'dependent_packages_count' => 0 }
    ])
    assert_equal 0, project.total_dependent_repos
    assert_equal 0, project.total_dependent_packages
  end
end