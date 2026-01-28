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

  test "reviewed scope includes only reviewed projects" do
    reviewed_project = Project.create!(url: 'https://github.com/test/reviewed', reviewed: true)
    unreviewed_false = Project.create!(url: 'https://github.com/test/unreviewed-false', reviewed: false)
    unreviewed_nil = Project.create!(url: 'https://github.com/test/unreviewed-nil', reviewed: nil)

    reviewed_ids = Project.reviewed.pluck(:id)

    assert_includes reviewed_ids, reviewed_project.id
    refute_includes reviewed_ids, unreviewed_false.id
    refute_includes reviewed_ids, unreviewed_nil.id
  end

  test "unreviewed scope includes projects with reviewed false or nil" do
    reviewed_project = Project.create!(url: 'https://github.com/test/reviewed', reviewed: true)
    unreviewed_false = Project.create!(url: 'https://github.com/test/unreviewed-false', reviewed: false)
    unreviewed_nil = Project.create!(url: 'https://github.com/test/unreviewed-nil', reviewed: nil)

    unreviewed_ids = Project.unreviewed.pluck(:id)

    refute_includes unreviewed_ids, reviewed_project.id
    assert_includes unreviewed_ids, unreviewed_false.id
    assert_includes unreviewed_ids, unreviewed_nil.id
  end

  test "update_keywords_from_contributors removes null bytes from keywords" do
    project = Project.create!(url: 'https://github.com/test/nullbyte')

    # Mock contributor_topics to return a hash with null bytes in keys
    project.stubs(:contributor_topics).returns({ "valid_keyword" => 5, "invalid\0keyword" => 3, "another_valid" => 4 })
    project.update_keywords_from_contributors
    project.reload

    # Should save all keywords with null bytes removed
    assert_equal 3, project.keywords_from_contributors.length
    assert_includes project.keywords_from_contributors, "valid_keyword"
    assert_includes project.keywords_from_contributors, "another_valid"
    assert_includes project.keywords_from_contributors, "invalidkeyword"
    refute_includes project.keywords_from_contributors, "invalid\0keyword"
  end

  test "update_keywords_from_contributors handles keywords that become blank after null byte removal" do
    project = Project.create!(url: 'https://github.com/test/allnullbytes')

    # Mock contributor_topics to return a hash with keywords that are only null bytes
    project.stubs(:contributor_topics).returns({ "\0" => 3, "\0\0" => 4, "valid" => 5 })
    project.update_keywords_from_contributors
    project.reload

    # Should only include the valid keyword, blank ones are filtered out
    assert_equal 1, project.keywords_from_contributors.length
    assert_includes project.keywords_from_contributors, "valid"
  end

  test "keywords getter returns empty array when nil" do
    project = Project.create!(url: 'https://github.com/test/nil-keywords')
    keywords = project.keywords
    assert_equal [], keywords
  end

  test "keywords getter works with normal keywords" do
    project = Project.create!(url: 'https://github.com/test/normal-keywords')
    project.update_columns(keywords: ['python', 'ruby', 'javascript'])

    keywords = project.keywords
    assert_equal 3, keywords.length
    assert_includes keywords, "python"
    assert_includes keywords, "ruby"
    assert_includes keywords, "javascript"
  end

  test "matching_topics does not raise error with clean keywords" do
    project = Project.create!(url: 'https://github.com/test/clean-keywords')
    project.update_columns(keywords: ['python', 'ruby', 'javascript'])

    # This should not raise an ArgumentError about null bytes
    assert_nothing_raised do
      project.matching_topics
    end
  end

  test "fetch_readme sanitizes null bytes from content" do
    project = Project.create!(url: 'https://github.com/test/readme-nullbytes')
    project.stubs(:readme_file_name).returns(nil)
    project.stubs(:download_url).returns(nil)

    # Mock the fallback HTTP response with null bytes
    mock_response = stub(success?: true, body: "Hello\u0000World")
    mock_conn = stub(get: mock_response)
    Faraday.stubs(:new).returns(mock_conn)

    project.fetch_readme
    assert_equal "HelloWorld", project.readme
  end

  test "search scope returns matching projects by name" do
    project = Project.create!(url: 'https://github.com/test/solar-panel', name: 'Solar Panel Tracker', reviewed: true)
    Project.create!(url: 'https://github.com/test/wind-turbine', name: 'Wind Turbine', reviewed: true)

    results = Project.search('solar')
    assert_includes results, project
    assert_equal 1, results.count
  end

  test "search scope returns matching projects by description" do
    project = Project.create!(url: 'https://github.com/test/energy-tool', name: 'Energy Tool', description: 'Monitors photovoltaic output', reviewed: true)

    results = Project.search('photovoltaic')
    assert_includes results, project
  end

  test "search scope returns matching projects by keywords" do
    project = Project.create!(url: 'https://github.com/test/climate-lib', name: 'Climate Lib', keywords: ['carbon', 'emissions'], reviewed: true)

    results = Project.search('carbon')
    assert_includes results, project
  end

  test "search scope only returns reviewed projects" do
    Project.create!(url: 'https://github.com/test/reviewed-proj', name: 'Solar Reviewed', reviewed: true)
    Project.create!(url: 'https://github.com/test/unreviewed-proj', name: 'Solar Unreviewed', reviewed: false)

    results = Project.search('solar')
    assert results.all?(&:reviewed?)
  end

  test "search scope returns all reviewed when query is blank" do
    Project.create!(url: 'https://github.com/test/proj-a', name: 'Project A', reviewed: true)
    Project.create!(url: 'https://github.com/test/proj-b', name: 'Project B', reviewed: true)

    results = Project.search('')
    assert_equal Project.reviewed.count, results.count
  end

  test "search scope returns all reviewed when query is nil" do
    results = Project.search(nil)
    assert_equal Project.reviewed.count, results.count
  end

  test "facets returns keyword and language counts for a scope" do
    Project.create!(
      url: 'https://github.com/test/facet-proj',
      name: 'Facet Project',
      keywords: ['solar', 'energy'],
      repository: { 'language' => 'Python' },
      reviewed: true
    )

    scope = Project.search('facet')
    facets = Project.facets(scope)

    assert facets.key?("keywords")
    assert facets.key?("language")
    assert facets["keywords"]["solar"] >= 1
    assert facets["language"]["Python"] >= 1
  end

  test "fetch_citation_file sanitizes null bytes from content" do
    project = Project.create!(url: 'https://github.com/test/citation-nullbytes')
    project.stubs(:citation_file_name).returns('CITATION.cff')
    project.stubs(:download_url).returns('https://example.com/download.zip')

    # Mock the HTTP response with null bytes in JSON
    mock_response = stub(success?: true, body: { 'contents' => "Title:\u0000Test" }.to_json)
    mock_conn = stub(get: mock_response)
    project.stubs(:ecosystem_http_client).returns(mock_conn)

    project.fetch_citation_file
    assert_equal "Title:Test", project.citation_file
  end
end