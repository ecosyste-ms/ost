require 'test_helper'

class ScienceScoreCalculatorTest < ActiveSupport::TestCase
  def setup
    @project = Project.create!(url: 'https://github.com/test/science-project')
  end

  test "calculate returns score and breakdown" do
    calculator = ScienceScoreCalculator.new(@project)
    result = calculator.calculate

    assert_not_nil result[:score]
    assert_not_nil result[:breakdown]
    assert_equal 100, result[:max_score]
  end

  test "check_citation_file detects citation file" do
    @project.citation_file = 'test citation content'
    calculator = ScienceScoreCalculator.new(@project)

    result = calculator.check_citation_file

    assert result[:present]
    assert_equal "CITATION.cff file", result[:description]
    assert_equal "Found CITATION.cff file", result[:details]
  end

  test "check_doi_in_readme detects DOIs" do
    @project.readme = "This research is published at https://doi.org/10.1234/example"
    calculator = ScienceScoreCalculator.new(@project)

    result = calculator.check_doi_in_readme

    assert result[:present]
    assert_equal "DOI references", result[:description]
    assert_match(/Found \d+ DOI reference/, result[:details])
  end

  test "check_academic_links detects academic sites" do
    @project.readme = "Published on arxiv.org and available at researchgate.net"
    calculator = ScienceScoreCalculator.new(@project)

    result = calculator.check_academic_links

    assert result[:present]
    assert_equal "Academic publication links", result[:description]
    assert_match(/arxiv\.org/, result[:details])
    assert_match(/researchgate\.net/, result[:details])
  end

  test "check_academic_committers detects academic emails" do
    @project.commits = {
      'committers' => [
        {'name' => 'John Doe', 'email' => 'john@university.edu', 'count' => 10},
        {'name' => 'Jane Smith', 'email' => 'jane@college.ac.uk', 'count' => 5},
        {'name' => 'Bob Wilson', 'email' => 'bob@gmail.com', 'count' => 3}
      ]
    }

    calculator = ScienceScoreCalculator.new(@project)
    result = calculator.check_academic_committers

    assert result[:present]
    assert_equal "Committers with academic emails", result[:description]
    assert_match(/2 of 3 committers/, result[:details])
    assert_equal 2, result[:committers].length
  end

  test "calculate_score returns percentage based on present indicators" do
    @project.citation_file = 'test citation content'
    @project.readme = "DOI: 10.1234/example"
    @project.joss_metadata = {'title' => 'Test Paper'}

    calculator = ScienceScoreCalculator.new(@project)
    result = calculator.calculate

    assert result[:score] > 0
    assert result[:score] <= 100
    assert result[:breakdown][:has_citation_file][:present]
    assert result[:breakdown][:has_doi_in_readme][:present]
    assert result[:breakdown][:has_joss_paper][:present]
  end

  test "calculate_score returns 0 when no indicators present" do
    calculator = ScienceScoreCalculator.new(@project)
    result = calculator.calculate

    assert_equal 0.0, result[:score]
    assert_not result[:breakdown][:has_citation_file][:present]
    assert_not result[:breakdown][:has_doi_in_readme][:present]
    assert_not result[:breakdown][:has_academic_links][:present]
  end

  test "check_institutional_owner returns false when no owner" do
    calculator = ScienceScoreCalculator.new(@project)
    result = calculator.check_institutional_owner

    assert_not result[:present]
  end
end
