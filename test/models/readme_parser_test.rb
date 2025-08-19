require 'test_helper'

class ReadmeParserTest < ActiveSupport::TestCase
  def setup
    @readme = <<-README
## Category 1
### Sub-Category 1
[Link 1](http://example.com/1) - Description 1
### Sub-Category 2
[Link 2](http://example.com/2) - Description 2
## Category 2
### Sub-Category 3
[Link 3](http://example.com/3) - Description 3
  README
    @parser = ReadmeParser.new(@readme)
  end
  
  def test_parse_links
    expected_links = {
      'Category 1' => {
        'Sub-Category 1' => [
          { name: 'Link 1', url: 'http://example.com/1', description: 'Description 1' }
        ],
        'Sub-Category 2' => [
          { name: 'Link 2', url: 'http://example.com/2', description: 'Description 2' }
        ]
      },
      'Category 2' => {
        'Sub-Category 3' => [
          { name: 'Link 3', url: 'http://example.com/3', description: 'Description 3' }
        ]
      }
    }
    assert_equal expected_links, @parser.parse_links
  end

  def test_parse_links_without_description
    readme_without_description = <<-README
## Category 1
### Sub-Category 1
[Link without description](http://example.com/1)
  README
    parser = ReadmeParser.new(readme_without_description)
    expected_links = {
      'Category 1' => {
        'Sub-Category 1' => [
          { name: 'Link without description', url: 'http://example.com/1', description: '' }
        ]
      }
    }
    assert_equal expected_links, parser.parse_links
  end

  def test_parse_links_with_malformed_markdown
    malformed_readme = <<-README
## Category 1
### Sub-Category 1
[Incomplete link](
[No closing bracket(http://example.com/2)
Link without brackets http://example.com/3
  README
    parser = ReadmeParser.new(malformed_readme)
    expected_links = {
      'Category 1' => {
        'Sub-Category 1' => []
      }
    }
    assert_equal expected_links, parser.parse_links
  end
end