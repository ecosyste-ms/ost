class ReadmeParser

  def self.load(url)
    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    markdown = response.body
    new(markdown)
  end

  attr_reader :readme

  def initialize(readme)
    @readme = readme
  end

  def ignored_categories
    ['Contents', 'Contributors', 'Artwork and License']
  end

  def links(category, sub_category)
    @links ||= parse_links
    @links[category][sub_category]
  end

  def parse_links
    links = {}
    current_category = nil
    current_sub_category = nil

    @readme.each_line do |line|
      if line.start_with?('## ')
        category = line[3..-1].strip
        if ignored_categories.include?(category)
          current_category = nil
        else
          current_category = category
          links[current_category] ||= {}
        end
      elsif current_category && line.start_with?('### ')
        current_sub_category = line[4..-1].strip
        links[current_category][current_sub_category] ||= []
      elsif current_category && line.include?('](')
        link_text_start_idx = line.index('[')
        link_text_end_idx = line.index(']')
        next unless link_text_start_idx && link_text_end_idx
        
        link_text = line[link_text_start_idx + 1...link_text_end_idx]
  
        link_url_start_idx = line.index('](')
        link_url_end_idx = link_url_start_idx ? line.index(')', link_url_start_idx + 2) : nil
        next unless link_url_start_idx && link_url_end_idx
        
        link_url = line[link_url_start_idx + 2...link_url_end_idx]
  
        description_start = line.index('-', link_url_end_idx)
        description = description_start ? line[description_start + 1..-1].strip : ''
  
        links[current_category][current_sub_category] ||= []
        links[current_category][current_sub_category] << { name: link_text, url: link_url, description: description }
      end
    end
  
    links
  end
end