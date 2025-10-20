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

  test "zenodo_domains returns zenodo domains" do
    project = Project.new
    assert_equal ['zenodo.org', 'www.zenodo.org'], project.zenodo_domains
  end

  test "readme_zenodo_urls extracts zenodo urls from readme" do
    readme = "Check out our DOI: https://zenodo.org/record/1234567"
    project = Project.new(readme: readme)
    assert_includes project.readme_zenodo_urls, "https://zenodo.org/record/1234567"
  end

  test "readme_zenodo_urls handles invalid uris gracefully" do
    readme = "Some text with invalid uri"
    project = Project.new(readme: readme)
    assert_equal [], project.readme_zenodo_urls
  end

  test "readme_zenodo_urls returns empty array when readme is blank" do
    project = Project.new(readme: nil)
    assert_equal [], project.readme_zenodo_urls
  end

  test "zenodo_dois filters dois for zenodo pattern" do
    readme = "DOI: https://doi.org/10.5281/zenodo.1234567 and https://doi.org/10.1234/other.doi"
    project = Project.new(readme: readme)
    assert_includes project.zenodo_dois, "10.5281/zenodo.1234567"
    refute_includes project.zenodo_dois, "10.1234/other.doi"
  end

  test "zenodo_badge_urls finds zenodo badge images" do
    readme = "[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.1234567.svg)](https://doi.org/10.5281/zenodo.1234567)"
    project = Project.new(readme: readme)
    assert_includes project.zenodo_badge_urls.first, "zenodo"
  end

  test "zenodo_badge_urls returns empty array when no badges" do
    readme = "No badges here"
    project = Project.new(readme: readme)
    assert_equal [], project.zenodo_badge_urls
  end

  test "zenodo_from_badge extracts url from doi badge" do
    readme = "[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.1234567.svg)](https://doi.org/10.5281/zenodo.1234567)"
    project = Project.new(readme: readme)
    assert_equal "https://doi.org/10.5281/zenodo.1234567", project.zenodo_from_badge
  end

  test "zenodo_from_badge extracts url from record link" do
    readme = "Visit https://zenodo.org/record/1234567 for more info"
    project = Project.new(readme: readme)
    assert_equal "https://zenodo.org/record/1234567", project.zenodo_from_badge
  end

  test "zenodo_from_badge returns nil when no badge found" do
    readme = "No zenodo badge here"
    project = Project.new(readme: readme)
    assert_nil project.zenodo_from_badge
  end

  test "zenodo_url prioritizes doi url" do
    readme = "[![DOI](https://zenodo.org/badge/377399301.svg)](https://zenodo.org/doi/10.5281/zenodo.10223090)"
    project = Project.new(readme: readme)
    assert_equal "https://zenodo.org/doi/10.5281/zenodo.10223090", project.zenodo_url
  end

  test "zenodo_url returns record url when no doi url" do
    readme = "Visit https://zenodo.org/record/1234567"
    project = Project.new(readme: readme)
    assert_equal "https://zenodo.org/record/1234567", project.zenodo_url
  end

  test "zenodo_url converts badge doi svg to doi url" do
    readme = "[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.7551310.svg)](https://example.com)"
    project = Project.new(readme: readme)
    assert_equal "https://doi.org/10.5281/zenodo.7551310", project.zenodo_url
  end

  test "zenodo_url returns nil when only badge svg without doi" do
    readme = "[![Badge](https://zenodo.org/badge/377399301.svg)](https://example.com)"
    project = Project.new(readme: readme)
    assert_nil project.zenodo_url
  end

  test "zenodo_url returns nil when no zenodo information" do
    readme = "Just some text with no zenodo info"
    project = Project.new(readme: readme)
    assert_nil project.zenodo_url
  end
end