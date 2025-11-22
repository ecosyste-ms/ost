require 'csv'

class Project < ApplicationRecord
  include EcosystemApiClient

  include Meilisearch::Rails
  extend Pagy::Meilisearch
  ActiveRecord_Relation.include Pagy::Meilisearch

  meilisearch if: :reviewed? do
    add_attribute :language
    searchable_attributes [:name, :description, :url, :keywords, :owner, :category, :sub_category, :rubric, :readme, :works, :citation_file]
    displayed_attributes [:id, :name, :description, :url, :keywords,  :owner, :category, :sub_category, :rubric, :readme, :works, :citation_file]
    filterable_attributes [:language, :keywords]

    sortable_attributes [:name, :score]

    faceting "sortFacetValuesBy": {'*'=> 'count'}
  end 

  validates :url, presence: true, uniqueness: { case_sensitive: false }

  has_many :votes, dependent: :delete_all
  has_many :issues, dependent: :delete_all
  has_many :releases, dependent: :delete_all

  has_many :climatetriage_issues, -> { good_first_issue }, class_name: 'Issue'

  scope :active, -> { where("(repository ->> 'archived') = ?", 'false') }
  scope :archived, -> { where("(repository ->> 'archived') = ?", 'true') }

  scope :language, ->(language) { where("(repository ->> 'language') = ?", language) }
  scope :owner, ->(owner) { where("(repository ->> 'owner') = ?", owner) }
  scope :keyword, ->(keyword) { where("keywords @> ARRAY[?]::varchar[]", keyword) }
  scope :reviewed, -> { where(reviewed: true) }
  scope :unreviewed, -> { where(reviewed: [false, nil]) }
  scope :matching_criteria, -> { where(matching_criteria: true) }
  scope :with_readme, -> { where.not(readme: nil) }
  scope :with_works, -> { where('length(works::text) > 2') }
  scope :with_repository, -> { where.not(repository: nil) }
  scope :with_commits, -> { where.not(commits: nil) }
  scope :with_keywords, -> { where.not(keywords: []) }
  scope :without_keywords, -> { where(keywords: []) }
  scope :with_packages, -> { where.not(packages: [nil, []]) }

  scope :with_keywords_from_contributors, -> { where.not(keywords_from_contributors: []) }
  scope :without_keywords_from_contributors, -> { where(keywords_from_contributors: []) }

  scope :with_joss, -> { where.not(joss_metadata: nil) }
  scope :scientific, -> { where('science_score >= ?', 20) }
  scope :highly_scientific, -> { where('science_score >= ?', 75) }

  def self.import_from_csv

    # url = 'https://raw.githubusercontent.com/protontypes/open-source-in-environmental-sustainability/main/open-source-in-environmental-sustainability/csv/projects.csv'
    url = 'https://gist.githubusercontent.com/andrew/44442a6a84395df81bc1b0a153c5abaf/raw/fb4d3ff68eb65ebca9c9387fadb30349e3563e1b/Projects-Gridview.csv'

    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    csv = response.body
    csv_data = CSV.new(csv, headers: true)

    csv_data.each do |row|
      next if row['git_url'].blank?
      project = Project.find_or_create_by(url: row['git_url'].downcase)
      project.name = row['project_name']
      project.description = row['oneliner']
      project.rubric = row['rubric']
      project.reviewed = true
      project.save
      project.sync_async unless project.last_synced_at.present?
    end
  end

  def self.import_from_joss
    puts "Starting JOSS import..."
    page = 1
    total_created = 0
    total_existing = 0

    loop do
      puts "Fetching page #{page}..."
      url = "https://joss.theoj.org/papers/published.json?page=#{page}"

      conn = Faraday.new(url: url) do |faraday|
        faraday.response :follow_redirects
        faraday.request :retry, max: 3, interval: 0.5, interval_randomness: 0.5, backoff_factor: 2
        faraday.adapter Faraday.default_adapter
      end

      response = conn.get
      break unless response.success?

      papers = JSON.parse(response.body)
      break if papers.empty?

      papers.each do |paper|
        next if paper['software_repository'].blank?

        # Normalize the URL (lowercase and remove trailing slash)
        repo_url = paper['software_repository'].downcase.chomp('/')

        existing_project = Project.find_by(url: repo_url)
        if existing_project.present?
          total_existing += 1
          # Update JOSS metadata if project exists
          existing_project.update(
            joss_metadata: paper
          )
        else
          project = Project.create(
            url: repo_url,
            name: paper['title'],
            description: "#{paper['title']} - Published in JOSS (#{paper['year']})",
            joss_metadata: paper
          )
          if project.persisted?
            total_created += 1
            project.sync_async
          end
        end
      end

      puts "Page #{page}: #{papers.size} papers processed"
      page += 1
    end

    puts "JOSS import complete!"
    puts "Total new projects created: #{total_created}"
    puts "Total existing projects found: #{total_existing}"
    puts "Grand total: #{total_created + total_existing}"
  end

  def self.import_esd_projects
    url = 'https://raw.githubusercontent.com/open-energy-transition/open-esd-analysis/refs/heads/main/esd_list.csv'

    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    csv = response.body
    csv_data = CSV.new(csv, headers: true)

    csv_data.each do |row|
      puts "Processing #{row['project_name']}"
      project_url = row['project_url']
      id = project_url.split('/').last
      project = Project.find_by(id: id)
      next unless project.present?
      project.update(esd: true)
    end
  end

  def self.science_score_analysis(scope = reviewed)
    projects = scope.where.not(science_score: nil)
    total_projects = projects.count

    return { error: "No projects with science scores found" } if total_projects.zero?

    # Calculate score statistics
    scores = projects.pluck(:science_score).compact
    avg_score = scores.sum / scores.size.to_f

    # Breakdown by indicator
    breakdowns = projects.pluck(:science_score_breakdown).compact

    indicator_stats = {
      has_citation_file: { count: 0, description: "CITATION.cff file" },
      has_codemeta: { count: 0, description: "codemeta.json file" },
      has_zenodo: { count: 0, description: ".zenodo.json file" },
      has_doi_in_readme: { count: 0, description: "DOI references" },
      has_academic_links: { count: 0, description: "Academic publication links" },
      has_academic_committers: { count: 0, description: "Academic email committers" },
      has_institutional_owner: { count: 0, description: "Institutional organization owner" },
      has_joss_paper: { count: 0, description: "JOSS paper" }
    }

    breakdowns.each do |breakdown|
      next unless breakdown.is_a?(Hash)
      breakdown = breakdown.with_indifferent_access
      breakdown_data = breakdown[:breakdown] || breakdown

      indicator_stats.each_key do |indicator|
        if breakdown_data[indicator] && breakdown_data[indicator][:present]
          indicator_stats[indicator][:count] += 1
        end
      end
    end

    # Calculate percentages
    indicator_stats.each do |key, value|
      value[:percentage] = ((value[:count].to_f / total_projects) * 100).round(1)
    end

    # Score distribution
    score_ranges = {
      "0-20 (Low)" => projects.where("science_score < ?", 20).count,
      "20-40 (Medium-Low)" => projects.where("science_score >= ? AND science_score < ?", 20, 40).count,
      "40-60 (Medium)" => projects.where("science_score >= ? AND science_score < ?", 40, 60).count,
      "60-80 (Medium-High)" => projects.where("science_score >= ? AND science_score < ?", 60, 80).count,
      "80-100 (High)" => projects.where("science_score >= ?", 80).count
    }

    {
      total_projects: total_projects,
      average_score: avg_score.round(2),
      median_score: scores.sort[scores.size / 2]&.round(2),
      min_score: scores.min&.round(2),
      max_score: scores.max&.round(2),
      score_distribution: score_ranges,
      indicators: indicator_stats.map do |key, value|
        {
          name: key,
          description: value[:description],
          count: value[:count],
          percentage: value[:percentage]
        }
      end.sort_by { |i| -i[:percentage] }
    }
  end

  def self.print_science_score_analysis(scope = reviewed)
    analysis = science_score_analysis(scope)

    return puts analysis[:error] if analysis[:error]

    puts "\n" + "="*80
    puts "SCIENCE SCORE™ ANALYSIS"
    puts "="*80
    puts "\nOVERALL STATISTICS"
    puts "-"*80
    puts "Total Projects:     #{analysis[:total_projects]}"
    puts "Average Score:      #{analysis[:average_score]}"
    puts "Median Score:       #{analysis[:median_score]}"
    puts "Min Score:          #{analysis[:min_score]}"
    puts "Max Score:          #{analysis[:max_score]}"

    puts "\nSCORE DISTRIBUTION"
    puts "-"*80
    analysis[:score_distribution].each do |range, count|
      percentage = ((count.to_f / analysis[:total_projects]) * 100).round(1)
      bar = "█" * (percentage / 2).to_i
      puts "#{range.ljust(20)} #{count.to_s.rjust(4)} (#{percentage.to_s.rjust(5)}%) #{bar}"
    end

    puts "\nINDICATOR BREAKDOWN"
    puts "-"*80
    puts "#{"Indicator".ljust(40)} Count   %"
    puts "-"*80
    analysis[:indicators].each do |indicator|
      bar = "█" * (indicator[:percentage] / 2).to_i
      puts "#{indicator[:description].ljust(40)} #{indicator[:count].to_s.rjust(4)} #{indicator[:percentage].to_s.rjust(5)}% #{bar}"
    end
    puts "="*80 + "\n"

    analysis
  end

  def self.joss_stats
    total_joss = with_joss.count
    reviewed_joss = reviewed.with_joss.count
    unreviewed_joss = unreviewed.with_joss.count
    unreviewed_with_keywords = unreviewed.with_joss.where.not(keywords: []).count
    unreviewed_without_keywords = unreviewed.with_joss.where(keywords: []).count

    puts "\n" + "="*80
    puts "JOSS PROJECT STATISTICS"
    puts "="*80
    puts "Total JOSS projects:                  #{total_joss}"
    puts "Reviewed JOSS projects:               #{reviewed_joss}"
    puts "Unreviewed JOSS projects:             #{unreviewed_joss}"
    puts "  - With keywords:                    #{unreviewed_with_keywords}"
    puts "  - Without keywords:                 #{unreviewed_without_keywords}"
    puts "="*80 + "\n"

    {
      total: total_joss,
      reviewed: reviewed_joss,
      unreviewed: unreviewed_joss,
      unreviewed_with_keywords: unreviewed_with_keywords,
      unreviewed_without_keywords: unreviewed_without_keywords
    }
  end

  def self.inspect_joss_metadata_fields
    # Helper to see what fields are available in JOSS metadata
    sample = with_joss.first
    return "No JOSS projects found" unless sample

    puts "\nSample JOSS metadata fields:"
    puts JSON.pretty_generate(sample.joss_metadata)
    sample.joss_metadata&.keys
  end

  def self.generic_tech_keywords
    # Reuse existing ignore_words plus space-separated variants that appear in JOSS tags
    ignore_words + [
      'machine learning', 'deep learning', 'data science', 'data analysis',
      'open source', 'high performance', 'time series', 'data processing'
    ]
  end

  def self.find_joss_candidates_by_keywords(min_keyword_matches: 2, limit: 100)
    # Get reviewed JOSS projects and extract keywords from available fields
    ost_joss = reviewed.with_joss
    ost_joss_count = ost_joss.count

    puts "Analyzing #{ost_joss_count} reviewed JOSS projects..."

    # Collect keywords from multiple JOSS metadata fields
    all_keywords = []
    projects_with_keywords = 0
    generic_filter = generic_tech_keywords

    ost_joss.find_each do |project|
      metadata = project.joss_metadata
      next unless metadata.present?

      keywords = []

      # JOSS tags are a comma-separated string
      if metadata['tags'].present?
        tags = metadata['tags'].is_a?(String) ? metadata['tags'].split(',') : metadata['tags']
        keywords.concat(tags)
      end

      # Also check for other possible fields
      if metadata['subjects'].present?
        subjects = metadata['subjects'].is_a?(String) ? metadata['subjects'].split(',') : metadata['subjects']
        keywords.concat(subjects)
      end

      # Also use repository keywords if available
      if project.keywords.present?
        keywords.concat(project.keywords)
      end

      # Filter out generic terms
      keywords = keywords.reject { |k| generic_filter.include?(k.to_s.downcase.strip) }

      if keywords.any?
        projects_with_keywords += 1
        all_keywords.concat(keywords.map { |k| k.to_s.downcase.strip })
      end
    end

    puts "Found keywords in #{projects_with_keywords} out of #{ost_joss_count} projects"

    if all_keywords.empty?
      puts "\nNo keywords found. Inspecting a sample JOSS metadata structure..."
      inspect_joss_metadata_fields
      return []
    end

    keyword_counts = all_keywords
      .group_by(&:itself)
      .transform_values(&:count)
      .sort_by { |k, v| -v }

    # Get common keywords (appearing in at least 2 projects)
    common_keywords = keyword_counts.select { |k, v| v >= 2 }.map(&:first)

    puts "Found #{common_keywords.size} common keywords across reviewed OST projects"
    puts "Top 20 keywords: #{keyword_counts.take(20).map(&:first).join(', ')}"

    # Find unreviewed JOSS projects with matching keywords
    other_joss = unreviewed.with_joss
    other_joss_total = other_joss.count

    puts "Checking #{other_joss_total} unreviewed JOSS projects..."

    candidates = []
    checked = 0

    other_joss.find_each do |project|
      metadata = project.joss_metadata
      next unless metadata.present?

      keywords = []

      # Parse tags as comma-separated string
      if metadata['tags'].present?
        tags = metadata['tags'].is_a?(String) ? metadata['tags'].split(',') : metadata['tags']
        keywords.concat(tags)
      end

      if metadata['subjects'].present?
        subjects = metadata['subjects'].is_a?(String) ? metadata['subjects'].split(',') : metadata['subjects']
        keywords.concat(subjects)
      end

      keywords.concat(project.keywords) if project.keywords.present?

      next if keywords.empty?

      checked += 1
      project_keywords = keywords.map { |k| k.to_s.downcase.strip }
      matching_keywords = project_keywords & common_keywords

      if matching_keywords.size >= min_keyword_matches
        candidates << {
          id: project.id,
          name: project.name,
          url: project.url,
          keywords: keywords.map(&:strip).uniq,
          matching_keywords: matching_keywords,
          match_count: matching_keywords.size,
          description: project.description,
          joss_year: project.joss_metadata&.dig('year'),
          joss_title: project.joss_metadata&.dig('title')
        }
      end
    end

    puts "Checked #{checked} projects with keywords"

    # Sort by match count
    candidates.sort_by! { |c| -c[:match_count] }

    puts "Found #{candidates.size} JOSS projects with #{min_keyword_matches}+ matching keywords"

    candidates.take(limit)
  end

  def self.print_joss_candidates(min_keyword_matches: 2, limit: 50)
    candidates = find_joss_candidates_by_keywords(min_keyword_matches: min_keyword_matches, limit: limit)

    puts "\n# JOSS Project Candidates for OST\n"
    puts "Showing top #{candidates.size} unreviewed JOSS projects\n\n"

    candidates.each_with_index do |candidate, index|
      puts "## #{index + 1}. #{candidate[:name]}\n"
      puts "- **URL**: #{candidate[:url]}"
      puts "- **JOSS Paper**: #{candidate[:joss_title]} (#{candidate[:joss_year]})" if candidate[:joss_year]
      puts "- **Matching Keywords** (#{candidate[:match_count]}): #{candidate[:matching_keywords].join(', ')}"
      puts "- **Description**: #{candidate[:description]}" if candidate[:description]
      puts "- **ID**: `#{candidate[:id]}`"
      puts ""
    end

    puts "---\n"
    puts "*To review a candidate, run:* `Project.find(ID).update(reviewed: true)`\n"

    candidates
  end

  def self.import_education
    url = 'https://raw.githubusercontent.com/protontypes/open-sustainable-technology/refs/heads/main/education.md'

    readme = ReadmeParser.load(url)

    urls = []

    readme.parse_links.each do |category, sub_categories|
      sub_categories.each do |sub_category, links|
        links.each do |link|
          conn = Faraday.new(url: link[:url].downcase) do |faraday|
            faraday.response :follow_redirects
            faraday.adapter Faraday.default_adapter
          end
          
          begin
            response = conn.get
            if response.success?
              url = response.env.url.to_s.downcase
            else
              url = link[:url].downcase
            end
          rescue
            url = link[:url].downcase
          end

          url.chomp!('/')

          urls << url

          project = Project.find_or_create_by(url: url)
          project.name = link[:name]
          project.description = link[:description]
          project.reviewed = true
          project.category = "Sustainable Development"
          project.sub_category = "Education"
          project.save
          project.sync_async unless project.last_synced_at.present?
        end
      end
    end
    
    # # mark projects that are no longer in the readme as unreviewed
    # removed = Project.where.not(url: urls).reviewed.where(category: "Sustainable Development", sub_category: "Education")
    # removed.each do |p|
    #   puts "Marking #{p.url} as unreviewed"
    # end

    # puts "Removed #{removed.length} projects"
    # removed.update_all(reviewed: false)
  end

  def self.import_from_readme
    url = 'https://raw.githubusercontent.com/protontypes/open-sustainable-technology/main/README.md'
    readme = ReadmeParser.load(url)

    urls = []

    readme.parse_links.each do |category, sub_categories|
      sub_categories.each do |sub_category, links|
        links.each do |link|
          conn = Faraday.new(url: link[:url].downcase) do |faraday|
            faraday.response :follow_redirects
            faraday.adapter Faraday.default_adapter
          end
          
          begin
            response = conn.get
            if response.success?
              url = response.env.url.to_s.downcase
            else
              url = link[:url].downcase
            end
          rescue
            url = link[:url].downcase
          end

          url.chomp!('/')

          urls << url

          project = Project.find_or_create_by(url: url)
          project.name = link[:name]
          project.description = link[:description]
          project.reviewed = true
          project.category = category
          project.sub_category = sub_category
          project.save
          project.sync_async unless project.last_synced_at.present?
        end
      end
    end
    
    # mark projects that are no longer in the readme as unreviewed
    removed = Project.where.not(url: urls).reviewed.where.not(sub_category: 'Education')
    removed.each do |p|
      puts "Marking #{p.url} as unreviewed"
    end

    puts "Removed #{removed.length} projects"
    removed.update_all(reviewed: false)
  end

  def self.discover_via_topics(limit=100)
    relevant_keywords.shuffle.first(limit).each do |topic|
      import_topic(topic)
    end
  end

  def self.discover_via_keywords(limit=100)
    relevant_keywords.shuffle.first(limit).each do |topic|
      import_keyword(topic)
    end
  end

  def self.keywords
    Rails.cache.fetch('project_keywords', expires_in: 24.hours) do
      Project.reviewed.pluck(:keywords).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
    end
  end

  def self.ignore_words
    [
      # Programming Languages
      'c', 'c-plus-plus', 'cpp', 'c-sharp', 'csharp', 'fortran', 'go', 'golang', 'go-lang', 'java', 'javascript', 'js', 'jsx',
      'julia', 'julia-language', 'kotlin', 'matlab', 'php', 'python', 'python-3', 'python3', 'r', 'rlang', 'ruby', 'rust', 'rust-lang',
      'scala', 'swift', 'typescript', 'typescript-definitions', 'typings',

      # Web Frameworks & Frontend
      'angular', 'bootstrap', 'django', 'django-rest-framework', 'express', 'expressjs', 'fastapi', 'flask', 'laravel', 'nextjs',
      'nuxt', 'nuxt-module', 'nuxtjs', 'rails', 'react', 'react-component', 'react-hooks', 'react-native', 'reactive', 'reactjs',
      'ruby-on-rails', 'spring', 'spring-boot', 'svelte', 'vue', 'vue-component', 'vue3', 'vuejs',
      'shiny', 'streamlit', 'streamlit-app', 'streamlit-webapp', 'flask-app', 'django-app', 'fastapi-app',

      # JavaScript/Frontend Tools
      'ajax', 'babel', 'canvas', 'd3', 'd3js', 'dom', 'electron', 'graphql', 'jquery', 'node', 'node-js', 'nodejs', 'polyfill',
      'webpack', 'aframe', 'threejs', 'webgl', 'webgl2', 'webxr',

      # CSS/Styling
      'css', 'sass', 'scss', 'material', 'styled-components', 'styleguide', 'tailwindcss', 'postcss',

      # Python Packages/Libraries
      'dask', 'flask', 'matplotlib', 'numba', 'numpy', 'pandas', 'pyqt5', 'pyspark', 'pytorch', 'scikit-learn', 'scipy', 'tensorflow', 'torch',
      'python-client', 'python-library', 'python-module', 'python-package', 'python-toolkit', 'python-wrapper', 'python-wrappers',
      'python3-package', 'pypi-package', 'python-awips', 'gdal-python', 'geopython',

      # R Packages
      'r-package', 'ggplot2', 'rstats', 'rstudio', 'cran', 'r-stats',

      # Data Science/ML/AI
      'ai', 'artificial-intelligence', 'big-data', 'chatgpt', 'cnn', 'computer-vision', 'data-science', 'deep-learning',
      'machine-learning', 'machine-learning-algorithms', 'machine-translation', 'machinelearning', 'ml', 'neural-network',
      'neural-networks', 'nlp', 'nlp-library', 'openai', 'openai-gym', 'gpt', 'llm', 'self-driving-car',

      # Databases
      'couchdb', 'database', 'elasticsearch', 'influxdb', 'mongodb', 'mysql', 'orm', 'postgres', 'postgresql', 'postgis',
      'redis', 'sql', 'sqlite', 'flat-file-db',

      # Cloud/Infrastructure
      'aws', 'aws-lambda', 'azure', 'azure-functions', 'cloud', 'cloud-functions', 'digitalocean', 'docker', 'docker-compose',
      'dockerfile', 'gcp', 'google-cloud', 'heroku', 'heroku-app', 'k8s', 'kubernetes', 'netlify', 'serverless', 'serverless-framework',
      'terraform', 'vercel', 's3',

      # DevOps/CI-CD/Testing
      'bdd', 'benchmark', 'ci', 'cd', 'ci/cd', 'continuous-integration', 'devops', 'integration-tests', 'jest', 'mocha',
      'test', 'testing', 'unit-test', 'unit-testing', 'test-coverage', 'build-tool', 'linting', 'code-quality',

      # Version Control/Git
      'git', 'github', 'github-action', 'github-actions',

      # Package Managers/Build Tools
      'cmake', 'conda-forge', 'helm', 'npm', 'npm-package', 'package-manager', 'poetry', 'yarn',

      # Development Tools/IDEs
      'debug', 'devcontainer', 'editor', 'eslint', 'eslint-plugin', 'eslintconfig', 'eslintplugin', 'lint', 'linter',
      'makefile', 'mypy', 'shell', 'terminal', 'vscode-extension', 'bash', 'bash-script', 'zsh',

      # Web/API/Backend
      'api', 'api-client', 'api-rest', 'api-wrapper', 'backend', 'browser', 'chrome', 'client', 'cors', 'fetch', 'frontend',
      'front-end', 'http', 'https', 'middleware', 'proxy', 'request', 'rest', 'rest-api', 'router', 'rpc', 'server',
      'web', 'web-api', 'web-components', 'web-framework', 'web3', 'webapp', 'webservice', 'website', 'websocket',

      # Mobile/IoT/Hardware
      'android', 'arduino', 'arduino-library', 'esp8266', 'flutter', 'home-assistant', 'home-automation', 'homeassistant',
      'ios', 'iot', 'iot-platform', 'iot-application', 'mobile', 'mqtt', 'mqtt-client', 'raspberry-pi', 'smart-meter',
      'smarthome', 'hardware',

      # Data/File Formats
      'ascii', 'binary', 'csv', 'encoding', 'decoding', 'hdf5', 'json', 'json-parser', 'netcdf', 'pdf', 'protobuf',
      'serialization', 'toml', 'xml', 'xml-parser', 'yaml',

      # Notebooks/Interactive
      'ipython-notebook', 'jupyter', 'jupyter-lab', 'jupyter-notebook', 'jupyter-notebooks', 'jupyterhub', 'notebook',
      'pluto-notebooks',

      # Monitoring/Logging
      'grafana', 'log', 'logger', 'logging', 'metrics', 'monitoring', 'prometheus', 'prometheus-exporter',

      # Generic Software Terms
      'addon', 'algorithm', 'algorithms', 'analysis', 'analytics', 'animation', 'app', 'application', 'array', 'async',
      'auth', 'authentication', 'automation', 'boilerplate', 'bot', 'cache', 'cli', 'client', 'code', 'collaboration',
      'collection', 'command', 'command-line', 'command-line-tool', 'compiler', 'component', 'components', 'computation',
      'computational', 'computing', 'concurrency', 'config', 'configuration', 'connector', 'console', 'containers', 'core',
      'cross-platform', 'date', 'definition', 'deploy', 'design', 'design-system', 'development', 'diff', 'directory',
      'distributed-systems', 'documentation', 'download', 'downloader', 'encryption', 'engine', 'engineering', 'env',
      'error', 'events', 'extension', 'file', 'filter', 'form', 'format', 'forms', 'framework', 'fs', 'function',
      'functional', 'functional-programming', 'functions', 'generator', 'gui', 'hash', 'helpers', 'hooks', 'icon', 'image',
      'immutable', 'import', 'infrastructure', 'input', 'io', 'language', 'library', 'list', 'management', 'metadata',
      'microservice', 'microservices', 'module', 'modules', 'monorepo', 'native', 'navigation', 'network', 'number',
      'object', 'oop', 'opensource', 'open-source', 'optimization', 'overview', 'package', 'parse', 'parser', 'path',
      'performance', 'pipeline', 'platform', 'plugin', 'programming', 'promise', 'proxy', 'push', 'pwa', 'query', 'queue',
      'random', 'real-time', 'regex', 'repository', 'runtime', 'sample', 'sample-code', 'schema', 'script', 'sdk', 'search',
      'security', 'sort', 'standard', 'state', 'static-analyzer', 'static-site-generator', 'storage', 'stream', 'string',
      'style', 'swagger', 'table', 'task', 'template', 'theme', 'tiles', 'tool', 'toolkit', 'tools', 'tree', 'ts', 'tuning',
      'type', 'types', 'ui', 'unicode', 'url', 'util', 'utilities', 'utility', 'utils', 'validate', 'validation', 'validator',
      'vector', 'video', 'view', 'workflow', 'wrapper',

      # Generic Scientific/Academic
      'algorithm', 'analysis', 'arxiv', 'article', 'bayesian', 'bayesian-inference', 'citation', 'classification', 'clustering',
      'coursework', 'data', 'data-analysis', 'data-analysis-python', 'data-visualisation', 'data-visualization', 'dataset',
      'datasets', 'deterministic', 'dissertation', 'education', 'empirical', 'experimental', 'learning', 'linear-algebra',
      'linear-programming', 'manuscript', 'math', 'model', 'modeling', 'modelling', 'models', 'monte-carlo', 'monte-carlo-simulation',
      'object-detection', 'optimization', 'paper', 'parameter-estimation', 'peer-reviewed', 'plotting', 'plotting-in-python',
      'preprint', 'publication', 'qualitative', 'quantitative', 'random-forest', 'random-walk', 'regression', 'reproducible',
      'reproducible-research', 'research', 'science', 'scientific', 'scientific-computations', 'scientific-computing',
      'scientific-machine-learning', 'scientific-names', 'scientific-research', 'scientific-visualization', 'scientific-workflows',
      'segmentation', 'sensitivity-analysis', 'simulation', 'solver', 'spatial', 'statistics', 'statistical', 'stochastic',
      'teaching', 'text-mining', 'theoretical', 'thesis', 'time', 'time-series', 'time-series-analysis', 'time-series-forecasting',
      'timeseries', 'trends', 'tutorial', 'tutorials', 'uncertainty-quantification', 'visualization',

      # Non-Environmental Scientific Domains
      'astronomy', 'astrophysics', 'biochemistry', 'biomedical', 'chemistry', 'clinical', 'complex-systems', 'cosmology',
      'genetics', 'healthcare', 'medical', 'medicine', 'mesh-generation', 'molecular-biology', 'particle-physics',
      'physics', 'optics', 'photonics', 'photonic', 'photonic-crystals', 'laser', 'beam', 'spectroscopy',
      'multidimensional spectroscopy', 'terahertz', 'holographic', 'quantum', 'quantum mechanics', 'quantum computing',
      'quantum-key-distribution', 'stellar', 'lattice', 'hydrodynamics', 'particles', 'particle-system', 'particle-based',
      'geoscience', 'geosciences', 'earth science',
      'reinforcement learning', 'reinforcement-learning', 'pomdp', 'mdp',
      'semiconductors', 'materials science', 'materials-science', 'defect', 'supercell', 'doping',
      'thermodynamics', 'fluid dynamics', 'fluid-dynamics',
      'fuzzy', 'fuzzy-logic', 'c-means',

      # Geographic/Mapping (generic tools, not domain-specific)
      'cartocss', 'gdal-python', 'geographic-information-systems', 'geospatial', 'gis', 'google-earth-engine', 'gtfs',
      'hafas', 'landsat', 'leaflet', 'leaflet-plugins', 'leafletjs', 'map', 'mapbox', 'mapping', 'maps', 'opengl',
      'openstreetmap', 'osm', 'raster', 'remote-sensing', 'satellite', 'satellite-data', 'satellite-imagery',
      'satellite-images', 'sentinel', 'sentinel-1', 'shapefile', 'transit', 'transport',

      # Business/Enterprise
      'amazon', 'blockchain', 'bitcoin', 'cms', 'credit', 'crm', 'crypto', 'ethereum', 'erp', 'facebook', 'finance',
      'google', 'microsoft', 'odoo', 'social',

      # Other/Misc
      '0x0lobersyko', '3d', 'acertea', 'accessibility', 'anakjalanan', 'ast', 'atmosphere', 'audio-processing', 'australia',
      'awesome', 'awesome-list', 'berlin', 'boost', 'bsd3', 'building', 'check', 'cnc', 'color', 'colors', 'course',
      'cpu', 'cuda', 'cuda-fortran', 'dashboard', 'dashboards', 'datacube', 'detection', 'digital-public-goods', 'docusaurus',
      'dom', 'dotnet', 'dts', 'earth-engine', 'electricity', 'email', 'emoji', 'energy', 'energy-monitor', 'environment',
      'epanet-python-toolkit', 'es2015', 'es6', 'fabric', 'farm', 'fast', 'firebase', 'first-good-issue', 'fleet-management',
      'fluentui', 'font', 'food', 'forecast', 'forecasting', 'france', 'game', 'gpu', 'gpu-acceleration', 'gpu-computing',
      'graph', 'hacktoberfest', 'hacktoberfest2020', 'hacktoberfest2021', 'herojoker', 'hfc', 'high-performance-computing',
      'hpc', 'html', 'html5', 'hyper-function-component', 'i18n', 'image-classification', 'image-database', 'image-processing',
      'image-segmentation', 'indoxcapital', 'jokiml', 'joss', 'jwt', 'linux', 'linux-foundation', 'macos', 'markdown',
      'matlab-python-interface', 'mechanical-engineering', 'mejarobot', 'mhkit-python', 'modbus', 'nasa', 'nasa-data', 'news',
      'nginx', 'nutrition', 'open-data', 'openapi', 'openfoodfacts', 'optuna', 'pathways', 'photography', 'pi0', 'privacy',
      'public-good', 'public-goods', 'pyam', 'risk', 'robotics', 'scenario', 'snakemake', 'sonarqube', 'sonarqube-plugin',
      'space', 'spark', 'apache-spark', 'spec', 'specification', 'svg', 'tag1', 'tag2', 'tauri', 'tea', 'teanager',
      'transmission', 'uk', 'windows', 'xarray', 'yeoman-generator', 'yii2', 'zigbee', 'evaluation'
    ]
  end

  def self.stop_words
    []
  end

  def self.update_matching_criteria
    unreviewed.find_each(&:update_matching_criteria)
  end

  def update_matching_criteria
    update(matching_criteria: matching_criteria?)
  end

  def self.potential_good_topics
    Project.unreviewed.where('vote_score > 0').pluck(:keywords).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse.select{|k,v| v > 1}.map(&:first) - ignore_words
  end

  def self.potential_ignore_words
    Project.unreviewed.where('vote_score < 0').pluck(:keywords).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse.select{|k,v| v > 1}.map(&:first) - ignore_words
  end

  def self.relevant_keywords
    Rails.cache.fetch('project_relevant_keywords', expires_in: 24.hours) do
      keywords.select{|k,v| v > 1}.map(&:first) - ignore_words
    end
  end

  def self.rubric_keywords(rubric)
    Project.where(rubric: rubric).pluck(:keywords).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def self.sync_least_recently_synced
    Project.where(last_synced_at: nil).or(Project.where("last_synced_at < ?", 1.day.ago)).order('last_synced_at asc nulls first').limit(500).each do |project|
      project.sync_async
    end
  end

  def self.sync_least_recently_synced_reviewed
    Project.reviewed.where(last_synced_at: nil).or(Project.reviewed.where("last_synced_at < ?", 1.day.ago)).order('last_synced_at asc nulls first').limit(500).each do |project|
      project.sync_async
    end
  end

  def self.sync_all
    Project.all.each do |project|
      project.sync_async
    end
  end

  def to_s
    name.presence || url
  end

  def repository_url
    repo_url = github_pages_to_repo_url(url)
    return repo_url if repo_url.present?
    url
  end

  def github_pages_to_repo_url(github_pages_url)
    return if github_pages_url.blank?
    match = github_pages_url.chomp('/').match(/https?:\/\/(.+)\.github\.io\/(.+)/)
    return nil unless match
  
    username = match[1]
    repo_name = match[2]
  
    "https://github.com/#{username}/#{repo_name}"
  end

  def first_created
    return unless repository.present?
    Time.parse(repository['created_at'])
  end

  def sync
    check_url
    return unless self.persisted?
    fetch_repository
    fetch_owner
    fetch_dependencies
    fetch_packages
    combine_keywords
    fetch_commits
    fetch_events
    fetch_issue_stats
    sync_issues if reviewed?
    fetch_citation_file if reviewed?
    fetch_readme if reviewed?
    sync_releases if reviewed?
    update_committers
    update_keywords_from_contributors
    update(last_synced_at: Time.now, matching_criteria: matching_criteria?)
    update_score
    update_science_score
    ping
  end

  def sync_async
    SyncProjectWorker.perform_async(id)
  end

  def check_url
    conn = Faraday.new(url: url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    update!(url: response.env.url.to_s) 
    # TODO avoid duplicates
  rescue ActiveRecord::RecordInvalid => e
    puts "Duplicate url #{url}"
    puts e.class
    destroy
  rescue
    puts "Error checking url for #{url}"
  end

  def combine_keywords
    all_keywords = []
    all_keywords += repository["topics"] if repository.present?
    all_keywords += packages.map{|p| p["keywords"]}.flatten if packages.present?
    # Reject blank keywords and those with null bytes (from external data sources)
    self.keywords = all_keywords.reject { |k| k.blank? || k.include?("\0") }.uniq { |keyword| keyword.downcase }.dup
    self.save
  rescue FrozenError
    puts "Error combining keywords for #{repository_url}"
  end

  def ping
    ping_urls.each do |url|
      Faraday.get(url, nil, {'User-Agent' => 'ost.ecosyste.ms'}) rescue nil
    end
  end

  def ping_urls
    ([repos_ping_url] + [issues_ping_url] + [commits_ping_url] + packages_ping_urls + [owner_ping_url]).compact.uniq
  end

  def repos_ping_url
    return unless repository.present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def issues_ping_url
    return unless repository.present?
    "https://issues.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def commits_ping_url
    return unless repository.present?
    "https://commits.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
  end

  def packages_ping_urls
    return [] unless packages.present?
    packages.map do |package|
      "https://packages.ecosyste.ms/api/v1/registries/#{package['registry']['name']}/packages/#{package['name']}/ping"
    end
  end

  def owner_ping_url
    return unless repository.present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/owner/#{repository['owner']}/ping"
  end

  def description
    return read_attribute(:description) if read_attribute(:description).present?
    return unless repository.present?
    repository["description"]
  end

  def repos_api_url
    "https://repos.ecosyste.ms/api/v1/repositories/lookup?url=#{repository_url}"
  end

  def repos_url
    return unless repository.present?
    "https://repos.ecosyste.ms/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}"
  end

  def fetch_repository
    conn = ecosystem_http_client(repos_api_url)

    response = conn.get
    return unless response.success?
    self.repository = JSON.parse(response.body)
    self.save
  rescue => e
    puts "Error fetching repository for #{repository_url}"
    puts e.message
    puts e.backtrace
  end

  def owner_api_url
    return unless repository.present?
    return unless repository["owner"].present?
    return unless repository["host"].present?
    return unless repository["host"]["name"].present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/owners/#{repository['owner']}"
  end

  def owner_url
    return unless repository.present?
    return unless repository["owner"].present?
    return unless repository["host"].present?
    return unless repository["host"]["name"].present?
    "https://repos.ecosyste.ms/hosts/#{repository['host']['name']}/owners/#{repository['owner']}"
  end

  def fetch_owner
    return unless owner_api_url.present?
    conn = ecosystem_http_client(owner_api_url)

    response = conn.get
    return unless response.success?
    self.owner = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching owner for #{repository_url}"
  end

  def timeline_url
    return unless repository.present?
    return unless repository["host"]["name"] == "GitHub"

    "https://timeline.ecosyste.ms/api/v1/events/#{repository['full_name']}/summary"
  end

  def fetch_events
    return unless timeline_url.present?
    conn = ecosystem_http_client(timeline_url)

    response = conn.get
    return unless response.success?
    summary = JSON.parse(response.body)

    conn = ecosystem_http_client(timeline_url+'?after='+1.year.ago.to_fs(:iso8601))

    response = conn.get
    return unless response.success?
    last_year = JSON.parse(response.body)

    self.events = {
      "total" => summary,
      "last_year" => last_year
    }
    self.save
  rescue
    puts "Error fetching events for #{repository_url}"
  end

  # TODO fetch repo dependencies
  # TODO fetch repo tags

  def packages_url
    "https://packages.ecosyste.ms/api/v1/packages/lookup?repository_url=#{repository_url}"
  end

  def fetch_packages
    conn = ecosystem_http_client(packages_url)

    response = conn.get
    return unless response.success?
    self.packages = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching packages for #{repository_url}"
  end

  def commits_api_url
    "https://commits.ecosyste.ms/api/v1/repositories/lookup?url=#{repository_url}"
  end

  def commits_url
    "https://commits.ecosyste.ms/repositories/lookup?url=#{repository_url}"
  end

  def fetch_commits
    conn = ecosystem_http_client(commits_api_url)
    response = conn.get
    return unless response.success?
    self.commits = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching commits for #{repository_url}"
  end

  def committers_names
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].map{|c| c["name"].downcase }.uniq
  end

  def committers
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"].map{|c| [c["name"].downcase, c["count"]]}.each_with_object(Hash.new {|h,k| h[k] = 0}) { |(x,d),h| h[x] += d }
  end

  def raw_committers
    return [] unless commits.present?
    return [] unless commits["committers"].present?
    commits["committers"]
  end

  def fetch_dependencies
    return unless repository.present?
    conn = ecosystem_http_client(repository['manifests_url'])
    response = conn.get
    return unless response.success?
    self.dependencies = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching dependencies for #{repository_url}"
  end

  def ignored_ecosystems
    ['actions', 'docker', 'homebrew']
  end

  def dependency_packages
    return [] unless dependencies.present?
    dependencies.map{|d| d["dependencies"]}.flatten.select{|d| d['direct'] }.reject{|d| ignored_ecosystems.include?(d['ecosystem']) }.map{|d| [d['ecosystem'],d["package_name"].downcase]}.uniq
  end

  def dependency_ecosystems
    return [] unless dependencies.present?
    dependencies.map{|d| d["dependencies"]}.flatten.select{|d| d['direct'] }.reject{|d| ignored_ecosystems.include?(d['ecosystem']) }.map{|d| d['ecosystem']}.uniq
  end

  def fetch_dependent_repos
    return unless packages.present?
    dependent_repos = []
    packages.each do |package|
      # TODO paginate
      # TODO group dependencies by repo
      dependent_repos_url = "https://repos.ecosyste.ms/api/v1/usage/#{package["ecosystem"]}/#{package["name"]}/dependencies"
      conn = ecosystem_http_client(dependent_repos_url)
      response = conn.get
      return unless response.success?
      dependent_repos += JSON.parse(response.body)
    end
    self.dependent_repos = dependent_repos.uniq
    self.save
  end

  def issues_api_url
    "https://issues.ecosyste.ms/api/v1/repositories/lookup?url=#{repository_url}"
  end

  def issue_stats_url
    "https://issues.ecosyste.ms/repositories/lookup?url=#{repository_url}"
  end

  def fetch_issue_stats
    conn = ecosystem_http_client(issues_api_url)
    response = conn.get
    return unless response.success?
    self.issues_stats = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching issues for #{repository_url}"
  end

  def language
    return unless repository.present?
    repository['language']
  end

  def language_with_default
    language.presence || 'Unknown'
  end

  def issue_stats
    i = read_attribute(:issues_stats) || {}
    JSON.parse(i.to_json, object_class: OpenStruct)
  end

  def update_score
    update_attribute :score, score_parts.sum
  end

  def update_science_score
    result = calculate_science_score_breakdown
    update(science_score: result[:score], science_score_breakdown: result)
  end

  def science_score_breakdown
    # Return stored breakdown from database
    # This method should only be called from views/API, never calculate on the fly
    breakdown = read_attribute(:science_score_breakdown)
    breakdown&.with_indifferent_access
  end

  def calculate_science_score_breakdown
    # This method should only be called from background jobs
    calculator = ScienceScoreCalculator.new(self)
    calculator.calculate
  end

  def score_parts
    [
      repository_score,
      packages_score,
      commits_score,
      dependencies_score,
      events_score
    ]
  end

  def repository_score
    return 0 unless repository.present?
    Math.log [
      (repository['stargazers_count'] || 0),
      (repository['open_issues_count'] || 0)
    ].sum
  end

  def packages_score
    return 0 unless packages.present?
    Math.log [
      packages.map{|p| p["downloads"] || 0 }.sum,
      packages.map{|p| p["dependent_packages_count"] || 0 }.sum,
      packages.map{|p| p["dependent_repos_count"] || 0 }.sum,
      packages.map{|p| p["docker_downloads_count"] || 0 }.sum,
      packages.map{|p| p["docker_dependents_count"] || 0 }.sum,
      packages.map{|p| p['maintainers'].map{|m| m['uuid'] } }.flatten.uniq.length
    ].sum
  end

  def commits_score
    return 0 unless commits.present?
    Math.log [
      (commits['total_committers'] || 0),
    ].sum
  end

  def dependencies_score
    return 0 unless dependencies.present?
    0
  end

  def events_score
    return 0 unless events.present?
    0
  end

  def language
    return unless repository.present?
    repository['language']
  end

  def owner_name
    return unless repository.present?
    repository['owner']
  end

  def avatar_url
    return unless repository.present?
    repository['icon_url']
  end

  def matching_criteria?
    good_topics? && external_users? && open_source_license? && active?
  end

  def high_quality?
    external_users? && open_source_license? && active?
  end

  def matching_topics
    (keywords & Project.relevant_keywords)
  end

  def no_bad_topics?
    (keywords & Project.stop_words).blank?
  end

  def good_topics?
    matching_topics.length > 0
  end

  def packages_count
    return 0 unless packages.present?
    packages.length
  end

  def monthly_downloads
    return 0 unless packages.present?
    packages.select{|p| p['downloads_period'] == 'last-month' }.map{|p| p["downloads"] || 0 }.sum
  end

  def downloads
    return 0 unless packages.present?
    packages.map{|p| p["downloads"] || 0 }.sum
  end

  def total_dependent_repos
    return 0 unless packages.present?
    packages.map{|p| p["dependent_repos_count"] || 0 }.sum
  end

  def total_dependent_packages
    return 0 unless packages.present?
    packages.map{|p| p["dependent_packages_count"] || 0 }.sum
  end

  def dependent_repos_urls
    return [] unless packages.present?

    repo_urls = Set.new

    packages.each do |p|
      page = 0
      Rails.logger.info "dependent_repos_urls: Processing package #{p['ecosystem']}/#{p['name']}"
      loop do
        page += 1
        break if page > 250
        break if p['ecosystem'].blank? || p['name'].blank?

        Rails.logger.info "dependent_repos_urls: Fetching page #{page} for #{p['ecosystem']}/#{p['name']}"
        url = "https://repos.ecosyste.ms/api/v1/usage/#{p['ecosystem']}/#{p['name']}/dependencies?per_page=50&page=#{page}"
        conn = ecosystem_http_client(url)
        response = conn.get
        unless response.success?
          Rails.logger.warn "dependent_repos_urls: Failed to fetch page #{page} for #{p['ecosystem']}/#{p['name']} (status: #{response.status})"
          break
        end
        data = JSON.parse(response.body)
        if data.blank?
          Rails.logger.info "dependent_repos_urls: No data on page #{page} for #{p['ecosystem']}/#{p['name']}, stopping"
          break
        end
        Rails.logger.info "dependent_repos_urls: Found #{data.size} dependencies on page #{page} for #{p['ecosystem']}/#{p['name']}"
        data.each do |dep|
          next unless dep['repository'].present?
          repo_urls << dep['repository']['html_url']
        end
      end
    end

    Rails.logger.info "dependent_repos_urls: Completed with #{repo_urls.size} unique repository URLs"
    repo_urls.to_a
  end

  def dependent_packages_urls
    return [] unless packages.present?

    package_urls = Set.new

    packages.each do |p|
      page = 0
      Rails.logger.info "dependent_packages_urls: Processing package #{p['registry']['name']}/#{p['name']}"
      loop do
        page += 1
        break if page > 250
        break if p['ecosystem'].blank? || p['name'].blank?

        Rails.logger.info "dependent_packages_urls: Fetching page #{page} for #{p['registry']['name']}/#{p['name']}"
        url = "https://packages.ecosyste.ms/api/v1/registries/#{p['registry']['name']}/packages/#{p['name']}/dependent_packages?per_page=50&page=#{page}"
        conn = ecosystem_http_client(url)
        response = conn.get
        unless response.success?
          Rails.logger.warn "dependent_packages_urls: Failed to fetch page #{page} for #{p['registry']['name']}/#{p['name']} (status: #{response.status})"
          break
        end
        data = JSON.parse(response.body)
        if data.blank?
          Rails.logger.info "dependent_packages_urls: No data on page #{page} for #{p['registry']['name']}/#{p['name']}, stopping"
          break
        end
        Rails.logger.info "dependent_packages_urls: Found #{data.size} dependencies on page #{page} for #{p['registry']['name']}/#{p['name']}"
        data.each do |dep|
          package_urls << dep['repository_url']
        end
      end
    end

    Rails.logger.info "dependent_packages_urls: Completed with #{package_urls.size} unique package URLs"
    package_urls.to_a
  end

  def issue_associations
    return [] unless issues_stats.present?
    (issues_stats['issue_author_associations_count'].keys + issues_stats['pull_request_author_associations_count'].keys).uniq
  end

  def external_users?
    issue_associations.any?{|a| a.to_s != 'OWNER' && a.to_s != 'MEMBER' }
  end

  def repository_license
    return nil unless repository.present?
    repository['license'] || repository.dig('metadata', 'files', 'license')
  end

  def packages_licenses
    return [] unless packages.present?
    packages.map{|p| p['licenses'] }.compact
  end

  def readme_license
    return nil unless readme.present?
    readme_image_urls.select{|u| u.downcase.include?('license') }.any?
  end

  def open_source_license?
    (packages_licenses + [repository_license] + [readme_license]).compact.uniq.any?
  end

  def past_year_total_commits
    return 0 unless commits.present?
    commits['past_year_total_commits'] || 0
  end

  def past_year_total_commits_exclude_bots
    return 0 unless commits.present?
    past_year_total_commits - past_year_total_bot_commits
  end

  def past_year_total_bot_commits
    return 0 unless commits.present?
    commits['past_year_total_bot_commits'].presence || 0
  end

  def commits_this_year?
    return false unless repository.present?
    if commits.present?
      past_year_total_commits_exclude_bots > 0
    else
      return false unless repository['pushed_at'].present?
      repository['pushed_at'] > 1.year.ago 
    end
  end

  def issues_this_year?
    return false unless issues_stats.present?
    return false unless issues_stats['past_year_issues_count'].present?
    (issues_stats['past_year_issues_count'] - issues_stats['past_year_bot_issues_count']) > 0
  end

  def pull_requests_this_year?
    return false unless issues_stats.present?
    return false unless issues_stats['past_year_pull_requests_count'].present?
    (issues_stats['past_year_pull_requests_count'] - issues_stats['past_year_bot_pull_requests_count']) > 0
  end

  def archived?
    return false unless repository.present?
    repository['archived']
  end

  def active?
    return false if archived?
    commits_this_year? || issues_this_year? || pull_requests_this_year?
  end

  def fork?
    return false unless repository.present?
    repository['fork']
  end

  def update_vote_count
    update vote_count: votes.count, vote_score: votes.sum(:score)
  end

  def self.import_topic(topic)
    resp = ecosystem_http_get("https://repos.ecosyste.ms/api/v1/topics/#{ERB::Util.url_encode(topic)}?per_page=100&sort=created_at&order=desc")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data['repositories'].map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        existing_project = Project.find_by(url: url.downcase)
        if existing_project.present?
          #puts 'already exists'
        else
          project = Project.create(url: url.downcase)
          project.sync_async
        end
      end
    end
  end

  def self.import_keyword(keyword)
    resp = ecosystem_http_get("https://packages.ecosyste.ms/api/v1/keywords/#{ERB::Util.url_encode(keyword)}?per_page=100&sort=created_at&order=desc")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data['packages'].reject{|p| p['status'].present? }.map{|p| p['repository_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        existing_project = Project.find_by(url: url.downcase)
        if existing_project.present?
          # puts 'already exists'
        else
          project = Project.create(url: url.downcase)
          project.sync_async
        end
      end
    end
  end

  def self.import_org(host, org)
    resp = ecosystem_http_get("https://repos.ecosyste.ms/api/v1/hosts/#{host}/owners/#{org}/repositories?per_page=100")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data.map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        existing_project = Project.find_by(url: url)
        if existing_project.present?
          # puts 'already exists'
        else
          project = Project.create(url: url)
          project.sync_async
        end
      end
    end
  end

  def citation_file_name
    return unless repository.present?
    return unless repository['metadata'].present?
    return unless repository['metadata']['files'].present?
    repository['metadata']['files']['citation']
  end

  def download_url
    return unless repository.present?
    repository['download_url']
  end

  def archive_url(path)
    return unless download_url.present?
    "https://archives.ecosyste.ms/api/v1/archives/contents?url=#{download_url}&path=#{path}"
  end

  def fetch_citation_file
    return unless citation_file_name.present?
    return unless download_url.present?
    conn = ecosystem_http_client(archive_url(citation_file_name))
    response = conn.get
    return unless response.success?
    json = JSON.parse(response.body)

    self.citation_file = json['contents']
    self.save
  rescue
    puts "Error fetching citation file for #{repository_url}"
  end

  def readme_file_name
    return unless repository.present?
    return unless repository['metadata'].present?
    return unless repository['metadata']['files'].present?
    repository['metadata']['files']['readme']
  end

  def readme_is_markdown?
    return unless readme_file_name.present?
    readme_file_name.downcase.ends_with?('.md') || readme_file_name.downcase.ends_with?('.markdown')
  end

  def fetch_readme
    if readme_file_name.blank? || download_url.blank?
      fetch_readme_fallback
    else
      return unless download_url.present?
      conn = ecosystem_http_client(archive_url(readme_file_name))
      response = conn.get
      return unless response.success?
      json = JSON.parse(response.body)

      self.readme = json['contents']
      self.save
    end
  rescue
    puts "Error fetching readme for #{repository_url}"
    fetch_readme_fallback
  end

  def fetch_readme_fallback
    file_name = readme_file_name.presence || 'README.md'
    conn = Faraday.new(url: raw_url(file_name)) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    self.readme = response.body
    self.save
  rescue
    puts "Error fetching readme for #{repository_url}"
  end

  def readme_url
    return unless repository.present?
    "#{repository['html_url']}/blob/#{repository['default_branch']}/#{readme_file_name}"
  end

  def preprocessed_readme
    return unless readme.present?
    text = readme
    # lowercase
    text = text.downcase
    # remove code blocks
    text = text.gsub(/```.*?```/m, '')
    # remove links
    text = text.gsub(/\[.*?\]\(.*?\)/m, '')
    # remove images
    text = text.gsub(/!\[.*?\]\(.*?\)/m, '')
    # remove headings
    text = text.gsub(/#+.*?\n/m, '')
    # remove lists
    text = text.gsub(/-.*?\n/m, '')
    # remove tables
    text = text.gsub(/\|.*?\n/m, '')
    # remove special characters
    text = text.gsub(/[^a-z0-9\s]/i, '')
    # newlines to spaces
    text = text.gsub(/\n/, ' ')
    # remove multiple spaces
    text = text.gsub(/\s+/, ' ')
    # remove leading and trailing spaces
    text = text.strip
  end

  def tokenized_readme
    return unless preprocessed_readme.present?
    
    # tokenizer = Tokenizers.from_pretrained("DWDMaiMai/tiktoken_cl100k_base")
    # tokenizer.encode(preprocessed_readme)
  end

  def parse_citation_file
    return unless citation_file.present?
    CFF::Index.read(citation_file).as_json
  rescue
    puts "Error parsing citation file for #{repository_url}"
  end

  def blob_url(path)
    return unless repository.present?
    "#{repository['html_url']}/blob/#{repository['default_branch']}/#{path}"
  end 

  def raw_url(path)
    return unless repository.present?
    "#{repository['html_url']}/raw/#{repository['default_branch']}/#{path}"
  end 

  def commiter_domains
    return unless commits.present?
    return unless commits['committers'].present?
    commits['committers'].map{|c| c['email'].split('@')[1].try(:downcase) }.reject{|e| e.nil? || ignored_domains.include?(e) || e.ends_with?('.local') || e.split('.').length ==1  }.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def ignored_domains
    ['users.noreply.github.com', "googlemail.com", "gmail.com", "hotmail.com", "outlook.com","yahoo.com","protonmail.com","web.de","example.com","live.com","icloud.com","hotmail.fr","yahoo.se","yahoo.fr"]
  end

  def sync_issues
    conn = ecosystem_http_client(issues_api_url)
    response = conn.get
    return unless response.success?
    issues_list_url = JSON.parse(response.body)['issues_url'] + '?per_page=1000&pull_request=false'
    # issues_list_url = issues_list_url + '&updated_after=' + last_synced_at.to_fs(:iso8601) if last_synced_at.present?

    conn = ecosystem_http_client(issues_list_url)
    response = conn.get
    return unless response.success?
    
    issues_json = JSON.parse(response.body)

    # TODO pagination
    # TODO upsert (plus unique index)

    issues_json.each do |issue|
      i = issues.find_or_create_by(number: issue['number']) 
      i.assign_attributes(issue)
      i.save(touch: false)
    end
  end

  def funding_links
    (package_funding_links + repo_funding_links + owner_funding_links + readme_funding_links).uniq
  end

  def package_funding_links
    return [] unless packages.present?
    packages.map{|pkg| pkg['metadata']['funding'] }.compact.map{|f| f.is_a?(Hash) ? f['url'] : f }.flatten.compact
  end

  def owner_funding_links
    return [] if repository.blank? || repository['owner_record'].blank? ||  repository['owner_record']["metadata"].blank?
    return [] unless repository['owner_record']["metadata"]['has_sponsors_listing']
    ["https://github.com/sponsors/#{repository['owner_record']['login']}"]
  end

  def repo_funding_links
    return [] if repository.blank? || repository['metadata'].blank? ||  repository['metadata']["funding"].blank?
    return [] if repository['metadata']["funding"].is_a?(String)
    repository['metadata']["funding"].map do |key,v|
      next if v.blank?
      case key
      when "github"
        Array(v).map{|username| "https://github.com/sponsors/#{username}" }
      when "tidelift"
        "https://tidelift.com/funding/github/#{v}"
      when "community_bridge"
        "https://funding.communitybridge.org/projects/#{v}"
      when "issuehunt"
        "https://issuehunt.io/r/#{v}"
      when "open_collective"
        "https://opencollective.com/#{v}"
      when "ko_fi"
        "https://ko-fi.com/#{v}"
      when "liberapay"
        "https://liberapay.com/#{v}"
      when "custom"
        v
      when "otechie"
        "https://otechie.com/#{v}"
      when "patreon"
        "https://patreon.com/#{v}"
      when "polar"
        "https://polar.sh/#{v}"
      when 'buy_me_a_coffee'
        "https://buymeacoffee.com/#{v}"
      when 'thanks_dev'
        "https://thanks.dev/#{v}"
      else
        v
      end
    end.flatten.compact
  end

  def readme_urls
    return [] unless readme.present?
    urls = URI.extract(readme.gsub(/[\[\]]/, ' '), ['http', 'https']).uniq
    # remove trailing garbage
    urls.map{|u| u.gsub(/\:$/, '').gsub(/\*$/, '').gsub(/\.$/, '').gsub(/\,$/, '').gsub(/\*$/, '').gsub(/\)$/, '').gsub(/\)$/, '').gsub('&nbsp;','') }
  end

  def readme_domains
    readme_urls.map{|u| URI.parse(u).host rescue nil }.compact.uniq
  end

  def funding_domains
    ['opencollective.com', 'ko-fi.com', 'liberapay.com', 'patreon.com', 'otechie.com', 'issuehunt.io', 'thanks.dev',
    'communitybridge.org', 'tidelift.com', 'buymeacoffee.com', 'paypal.com', 'paypal.me','givebutter.com', 'polar.sh']
  end

  def readme_funding_links
    urls = readme_urls.select{|u| funding_domains.any?{|d| u.include?(d) } || u.include?('github.com/sponsors') }.reject{|u| ['.svg', '.png'].include? File.extname(URI.parse(u).path) }
    # remove anchors
    urls = urls.map{|u| u.gsub(/#.*$/, '') }.uniq
    # remove sponsor/9/website from open collective urls
    urls = urls.map{|u| u.gsub(/\/sponsor\/\d+\/website$/, '') }.uniq
  end

  def doi_domains
    ['doi.org', 'dx.doi.org', 'www.doi.org']
  end

  def readme_doi_urls
    readme_urls.select{|u| doi_domains.include?(URI.parse(u).host) }.uniq
  end

  def dois
    readme_doi_urls.map{|u| URI.parse(u).path.gsub(/^\//, '') }.uniq
  end

  def fetch_works
    works = {}
    readme_doi_urls.each do |url|
      openalex_url = "https://api.openalex.org/works/#{url}"
      conn = Faraday.new(url: openalex_url) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      response = conn.get
      if response.success?
        works[url] = JSON.parse(response.body)
      else
        works[url] = nil
      end
    end
    self.works = works
    self.save
  end
  
  def citation_counts
    works.select{|k,v| v.present? }.map{|k,v| [k, v['counts_by_year'].map{|h| h["cited_by_count"]}.sum] }.to_h
  end

  def total_citations
    citation_counts.values.sum
  end

  def first_work_citations
    citation_counts.values.first
  end

  def zenodo_domains
    ['zenodo.org', 'www.zenodo.org']
  end

  def readme_zenodo_urls
    readme_urls.select{|u| zenodo_domains.include?(URI.parse(u).host) }.uniq
  rescue URI::InvalidURIError
    []
  end

  def zenodo_dois
    dois.select{|doi| doi.start_with?('10.5281/zenodo') }
  end

  def zenodo_badge_urls
    return [] unless readme.present?
    readme_image_urls.select{|u| u.match?(/zenodo/i) }
  end

  def zenodo_from_badge
    return nil unless readme.present?
    badge_match = readme.scan(/\[!\[DOI\]\(https:\/\/zenodo\.org\/badge\/DOI\/(10\.5281\/zenodo\.\d+)\.svg\)\]\((https:\/\/doi\.org\/10\.5281\/zenodo\.\d+)\)/i).first
    badge_match&.last || readme.scan(/https:\/\/(?:www\.)?zenodo\.org\/(?:badge\/|record\/|doi\/)(\d+)/i).flatten.first&.then{|id| "https://zenodo.org/record/#{id}" }
  end

  def zenodo_url
    return nil if readme_zenodo_urls.empty?

    urls = readme_zenodo_urls

    doi_url = urls.find{|u| u.match?(/zenodo\.org\/doi\/10\.5281\/zenodo\.\d+/) }
    return doi_url if doi_url

    record_url = urls.find{|u| u.match?(/zenodo\.org\/record\/\d+/) }
    return record_url if record_url

    badge_doi = urls.find{|u| u.match?(/zenodo\.org\/badge\/DOI\/10\.5281\/zenodo\.\d+\.svg/) }
    if badge_doi
      doi_match = badge_doi.match(/10\.5281\/zenodo\.\d+/)
      return "https://doi.org/#{doi_match[0]}" if doi_match
    end

    nil
  end

  def readme_image_urls
    return [] unless readme.present?
    urls = readme.scan(/!\[.*?\]\((.*?)\)/).flatten.compact.uniq

    # also sc`an for html images
    urls += readme.scan(/<img.*?src="(.*?)"/).flatten.compact.uniq

    # turn relative urls into absolute urls
    # remove anything after a space
    urls = urls.map{|u| u.split(' ').first }.compact.uniq
    
    urls = urls.map do |u|
      if !u.starts_with?('http')
        # if url starts with slash or alpha character, prepend repo url
        if u.starts_with?('/') || u.match?(/^[[:alpha:]]/)
          raw_url(u)
        end
      else
        u
      end
    end.compact
  end

  def update_committers
    return unless commits.present?
    return unless commits['committers'].present?
    return unless reviewed?

    # Filter out bots and limit to top committers
    human_committers = commits['committers'].reject { |c| bot_committer?(c) }
    top_committers = human_committers.sort_by { |c| -(c['count'] || 0) }.first(50)

    top_committers.each do |committer|
      c = Contributor.find_or_create_by(email: committer['email'])

      # Skip if somehow a bot got through
      next if c.bot?

      # Limit topic accumulation to prevent unbounded growth
      # Sanitize keywords to remove null bytes before adding
      if keywords.present? && c.topics.size < 100
        clean_keywords = keywords.reject { |k| k.blank? || k.include?("\0") }
        new_topics = (c.topics + clean_keywords).uniq.first(100)
        c.topics = new_topics
      end

      # Sanitize categories before adding
      c.categories = (c.categories + [category]).uniq.reject { |cat| cat.blank? || cat.include?("\0") }.first(20) if category
      c.sub_categories = (c.sub_categories + [sub_category]).uniq.reject { |sub| sub.blank? || sub.include?("\0") }.first(20) if sub_category
      c.reviewed_project_ids = (c.reviewed_project_ids + [id]).uniq.first(200)
      c.reviewed_projects_count = c.reviewed_project_ids.length
      c.update(committer.except('count'))
    end
  end

  private

  def bot_committer?(committer)
    email = committer['email'].to_s.downcase
    name = committer['name'].to_s.downcase

    return true if Contributor.bot_email?(email)
    return true if name.include?('[bot]')
    return true if name.end_with?('bot') && !name.include?(' ')
    return true if name == 'github actions'
    return true if name == 'dependabot'
    return true if name == 'pre-commit-ci'
    return true if name == 'allcontributors'

    false
  end

  public

  def contributors
    return unless commits.present?
    return unless commits['committers'].present?
    Contributor.where(email: commits['committers'].map{|c| c['email'] }.uniq)
  end

  def contributor_topics(limit: 10, minimum: 3)
    return {} unless commits.present?
    return {} unless commits['committers'].present?
    return {} unless contributors.length > 1

    ignored_keywords = (keywords + Project.ignore_words).uniq

    # Filter out null bytes and blank topics before processing
    all_topics = contributors.flat_map { |c| c.topics }
                             .reject { |t| t.blank? || t.include?("\0") || ignored_keywords.include?(t) }

    # Group by the stemmed version of the topic
    grouped_topics = all_topics.group_by { |topic| topic.stem }

    # For each group, keep one of the original topics and count the occurrences
    topic_counts = grouped_topics.map do |stemmed_topic, original_topics|
      [original_topics.first, original_topics.size]
    end.to_h

    popular_topics = topic_counts.reject{|t,c| c < minimum }.sort_by { |topic, count| -count }.first(limit).to_h
  end

  def update_keywords_from_contributors
    ct = contributor_topics(limit: 10, minimum: 3)
    sanitized_keywords = ct.keys.map { |k| k.gsub(/\u0000/, '') }.reject(&:blank?)
    update(keywords_from_contributors: sanitized_keywords) if sanitized_keywords.present?
  rescue ArgumentError => e
    Rails.logger.error("Failed to update keywords_from_contributors for project #{id}: #{e.message}")
  end

  def self.unique_keywords_for_category(category)
    Rails.cache.fetch("project_unique_keywords_category_#{category}", expires_in: 24.hours) do
      # Get all keywords from all categories
      all_keywords = Project.where.not(category: category).pluck(:keywords).flatten

      # Get keywords from the specific category
      category_keywords = Project.where(category: category).pluck(:keywords).flatten

      # Get keywords that only appear in the specific category
      unique_keywords = category_keywords - all_keywords

      # remove stop words
      unique_keywords = unique_keywords - ignore_words

      # Group the unique keywords by their values and sort them by the size of each group
      sorted_keywords = unique_keywords.group_by { |keyword| keyword }.sort_by { |keyword, occurrences| -occurrences.size }.map(&:first)
      sorted_keywords
    end
  end

  def self.unique_keywords_for_sub_category(subcategory)
    Rails.cache.fetch("project_unique_keywords_subcategory_#{subcategory}", expires_in: 24.hours) do
      # Get all keywords from all subcategory
      all_keywords = Project.where.not(sub_category: subcategory).pluck(:keywords).flatten

      # Get keywords from the specific subcategory
      subcategory_keywords = Project.where(sub_category: subcategory).pluck(:keywords).flatten

      # Get keywords that only appear in the specific subcategory
      unique_keywords = subcategory_keywords - all_keywords

      # remove stop words
      unique_keywords = unique_keywords - ignore_words

      # Group the unique keywords by their values and sort them by the size of each group
      sorted_keywords = unique_keywords.group_by { |keyword| keyword }.sort_by { |keyword, occurrences| -occurrences.size }.map(&:first)
      sorted_keywords
    end
  end

  def self.all_category_keywords
    Rails.cache.fetch('project_all_category_keywords', expires_in: 24.hours) do
      Project.where.not(category: nil).pluck(:category).uniq.map do |category|
        {
          category: category,
          keywords: unique_keywords_for_category(category)
        }
      end
    end
  end

  def self.all_sub_category_keywords
    Rails.cache.fetch('project_all_sub_category_keywords', expires_in: 24.hours) do
      Project.where.not(sub_category: nil).pluck(:sub_category).uniq.map do |subcategory|
        {
          sub_category: subcategory,
          keywords: unique_keywords_for_sub_category(subcategory)
        }
      end
    end
  end

  def suggest_category
    return unless keywords.present?

    cat = Project.all_category_keywords.map do |category|
      {
        category: category[:category],
        score: (keywords & category[:keywords]).length
      }
    end.sort_by{|c| -c[:score] }.first
    return nil if cat[:score] == 0
    cat
  end

  def suggest_sub_category
    return unless keywords.present?

    cat = Project.all_sub_category_keywords.map do |subcategory|
      {
        sub_category: subcategory[:sub_category],
        score: (keywords & subcategory[:keywords]).length
      }
    end.sort_by{|c| -c[:score] }.first
    return nil if cat[:score] == 0
    cat
  end

  def self.category_tree
    Rails.cache.fetch('project_category_tree', expires_in: 24.hours) do
      sql = <<-SQL
        SELECT category, sub_category, COUNT(*)
        FROM projects
        WHERE projects.reviewed = true
        GROUP BY category, sub_category
      SQL

      results = ActiveRecord::Base.connection.execute(sql)

      results.group_by { |row| row['category'] }.map do |category, rows|
        {
          category: category,
          count: rows.sum { |row| row['count'] },
          sub_categories: rows.map do |row|
            {
              sub_category: row['sub_category'],
              count: row['count']
            }
          end
        }
      end
    end
  end

  def self.sync_dependencies(min_count: 10)
    dependencies = Project.reviewed.map(&:dependency_packages).flatten(1).group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse

    dependencies.each do |(ecosystem, package_name), count|
      puts "Checking #{ecosystem} #{package_name}"

      dependency = Dependency.find_or_create_by(ecosystem: ecosystem, name: package_name)

      dependency.update(count: count)

      next if dependency.package.present?

      dependency.sync_package if count > min_count
    end
  end

  def sync_releases
    return unless repository.present?
    return unless repository['releases_url'].present?

    conn = ecosystem_http_client(repository['releases_url'] + '?per_page=1000')
    response = conn.get
    return unless response.success?
    releases = JSON.parse(response.body)

    releases.each do |release|
      r = Release.find_or_create_by(project_id: id, uuid: release['uuid'])
      r.update(release.except('release_url'))
    end
  end
end
