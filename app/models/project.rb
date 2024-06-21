require 'csv'

class Project < ApplicationRecord

  validates :url, presence: true, uniqueness: { case_sensitive: false }

  has_many :votes, dependent: :delete_all
  has_many :issues, dependent: :delete_all

  has_many :climatetriage_issues, -> { good_first_issue }, class_name: 'Issue'

  scope :active, -> { where("(repository ->> 'archived') = ?", 'false') }
  scope :archived, -> { where("(repository ->> 'archived') = ?", 'true') }

  scope :language, ->(language) { where("(repository ->> 'language') = ?", language) }
  scope :owner, ->(owner) { where("(repository ->> 'owner') = ?", owner) }
  scope :keyword, ->(keyword) { where("keywords @> ARRAY[?]::varchar[]", keyword) }
  scope :reviewed, -> { where(reviewed: true) }
  scope :unreviewed, -> { where(reviewed: nil) }
  scope :matching_criteria, -> { where(matching_criteria: true) }
  scope :with_readme, -> { where.not(readme: nil) }
  scope :with_works, -> { where('length(works::text) > 2') }
  scope :with_repository, -> { where.not(repository: nil) }
  scope :with_commits, -> { where.not(commits: nil) }
  scope :with_keywords, -> { where.not(keywords: []) }
  scope :without_keywords, -> { where(keywords: []) }

  scope :with_keywords_from_contributors, -> { where.not(keywords_from_contributors: []) }
  scope :without_keywords_from_contributors, -> { where(keywords_from_contributors: []) }

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
    removed = Project.where.not(url: urls).reviewed
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
    @keywords ||= Project.reviewed.pluck(:keywords).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def self.ignore_words
    ['0x0lobersyko', '3d', 'tag1', 'tag2', 'accessibility', 'acertea', 'addon', 'ai', 'ajax', 'algorithms', 'amazon', 'anakjalanan', 'analysis', 'analytics', 'android', 'angular', 'animation', 
    'apache-spark', 'api', 'api-client', 'api-rest', 'api-wrapper', 'app', 'arduino', 'array', 'artificial-intelligence', 'ast', 'async', 'atmosphere', 'australia', 'auth', 'authentication', 
    'automation', 'awesome', 'awesome-list', 'aws', 'azure', 'babel', 'backend', 'bash', 'bash-script', 'bdd', 'benchmark', 'big-data', 'bitcoin', 'blockchain', 'boilerplate', 'bootstrap', 
    'bot', 'browser', 'bsd3', 'building', 'c', 'c-plus-plus', 'cache', 'canvas', 'chatgpt', 'check', 'chrome', 'citation', 'classification', 'cli', 'client', 'cloud', 'clustering', 'cmake', 
    'cms', 'cnc', 'cnn', 'code', 'collaboration', 'collection', 'color', 'colors', 'command', 'command-line', 'command-line-tool', 'compiler', 'component', 'components', 'computer-vision', 
    'computing', 'concurrency', 'config', 'configuration', 'console', 'containers', 'core', 'couchdb', 'course', 'cpp', 'cpu', 'cran', 'credit', 'cross-platform', 'crypto', 'csharp', 'css', 
    'cuda', 'cuda-fortran', 'd3', 'd3js', 'dashboard', 'dashboards', 'dask', 'data', 'data-analysis', 'data-analysis-python', 'data-science', 'data-visualization', 'database', 'datacube', 
    'dataset', 'datasets', 'date', 'debug', 'deep-learning', 'definition', 'deploy', 'design', 'design-system', 'devops', 'diff', 'digital-public-goods', 'directory', 'distributed-systems', 
    'django', 'docker', 'documentation', 'dom', 'dotnet', 'download', 'downloader', 'dts', 'earth-engine', 'editor', 'education', 'elasticsearch', 'electricity', 'electron', 'email', 'emoji', 
    'encryption', 'energy', 'energy-monitor', 'engineering', 'env', 'environment', 'epanet-python-toolkit', 'erp', 'error', 'es2015', 'es6', 'eslint', 'eslint-plugin', 'eslintconfig', 
    'eslintplugin', 'esp8266', 'ethereum', 'events', 'express', 'expressjs', 'extension', 'fabric', 'facebook', 'farm', 'fast', 'fastapi', 'fetch', 'file', 'filter', 'finance', 'firebase', 
    'first-good-issue', 'flask', 'flat-file-db', 'fleet-management', 'fluentui', 'flutter', 'font', 'food', 'forecast', 'forecasting', 'form', 'format', 'forms', 'fortran', 'framework', 
    'front-end', 'frontend', 'fs', 'function', 'functional', 'functional-programming', 'functions', 'game', 'gdal-python', 'generator', 'geographic-information-systems', 'geopython', 
    'geospatial', 'ggplot2', 'gis', 'git', 'github', 'github-action', 'github-actions', 'go', 'golang', 'google', 'google-cloud', 'google-earth-engine', 'gpt', 'gpu', 'gpu-acceleration', 
    'gpu-computing', 'grafana', 'graph', 'graphql', 'gtfs', 'gui', 'hacktoberfest', 'hacktoberfest2020', 'hacktoberfest2021', 'hash', 'helm', 'helpers', 'herojoker', 'hfc', 
    'high-performance-computing', 'home-assistant', 'home-automation', 'homeassistant', 'hooks', 'hpc', 'html', 'html5', 'http', 'https', 'hyper-function-component', 'i18n', 'icon', 'image', 
    'image-classification', 'image-database', 'image-processing', 'image-segmentation', 'immutable', 'import', 'indoxcapital', 'influxdb', 'infrastructure', 'input', 'integration-tests', 'io', 
    'iobroker', 'ios', 'iot', 'iot-platform', 'ipython-notebook', 'java', 'javascript', 'jest', 'jokiml', 'joss', 'jquery', 'js', 'json', 'jsx', 'julia', 'jupyter', 'jupyter-lab', 
    'jupyter-notebook', 'jupyter-notebooks', 'jupyterhub', 'jwt', 'k8s', 'kotlin', 'kubernetes', 'landsat', 'language', 'laravel', 'leaflet', 'leaflet-plugins', 'library', 'lidar', 
    'linear-programming', 'lint', 'linux', 'linux-foundation', 'llm', 'log', 'logger', 'logging', 'machine-learning', 'machine-learning-algorithms', 'machine-translation', 'macos', 
    'management', 'manuscript', 'map', 'mapbox', 'mapping', 'maps', 'markdown', 'material', 'math', 'matlab', 'matlab-python-interface', 'matplotlib', 'mechanical-engineering', 'mejarobot', 
    'metadata', 'metrics', 'mhkit-python', 'microservice', 'microservices', 'microsoft', 'middleware', 'ml', 'mobile', 'mocha', 'modbus', 'model', 'modeling', 'modelling', 'models', 'module', 
    'modules', 'mongodb', 'monitoring', 'monorepo', 'monte-carlo-simulation', 'mqtt', 'mypy', 'mysql', 'nasa', 'nasa-data', 'native', 'natural-language-processing', 'netcdf', 'network', 
    'neural-network', 'neural-networks', 'news', 'nextjs', 'nlp', 'nlp-library', 'node', 'node-js', 'nodejs', 'npm', 'npm-package', 'numba', 'number', 'numpy', 'nutrition', 'nuxt', 
    'nuxt-module', 'nuxtjs', 'object', 'object-detection', 'odoo', 'open-data', 'open-source', 'openai', 'openai-gym', 'openapi', 'openfoodfacts', 'opensource', 'openstreetmap', 
    'optimization', 'orm', 'osm', 'overview', 'package', 'package-manager', 'pandas', 'parse', 'parser', 'path', 'pdf', 'peer-reviewed', 'performance', 'php', 'pi0', 'pipeline', 'platform', 
    'plotting', 'plotting-in-python', 'plugin', 'pluto-notebooks', 'poetry', 'polyfill', 'postcss', 'postgis', 'postgres', 'postgresql', 'programming', 'prometheus', 'prometheus-exporter', 
    'promise', 'protobuf', 'proxy', 'public-good', 'public-goods', 'push', 'pwa', 'pyam', 'pypi-package', 'pyqt5', 'pyspark', 'python', 'python-3', 'python-awips', 'python-client', 
    'python-library', 'python-module', 'python-package', 'python-toolkit', 'python-wrapper', 'python-wrappers', 'python3', 'python3-package', 'pytorch', 'query', 'queue', 'r', 'r-package', 
    'rails', 'random', 'random-walk', 'raspberry-pi', 'raster', 'react', 'react-component', 'react-hooks', 'react-native', 'reactive', 'reactjs', 'real-time', 'redis', 'redux', 'regex', 
    'regression', 'remote-sensing', 'reproducible-research', 'request', 'rest', 'rest-api', 'risk', 'robotics', 'router', 'rpc', 'rstats', 'rstudio', 'ruby', 'ruby-on-rails', 'runtime', 
    'rust', 'rust-lang', 's3', 'sample', 'sample-code', 'sass', 'satellite', 'satellite-data', 'satellite-imagery', 'satellite-images', 'scala', 'scenario', 'schema', 'science', 
    'scientific', 'scientific-computations', 'scientific-computing', 'scientific-machine-learning', 'scientific-names', 'scientific-research', 'scientific-visualization', 
    'scientific-workflows', 'scikit-learn', 'scipy', 'script', 'scss', 'sdk', 'search', 'security', 'segmentation', 'self-driving-car', 'sentinel', 'sentinel-1', 'serialization', 
    'server', 'serverless', 'shell', 'simulation', 'smart-meter', 'smarthome', 'snakemake', 'sort', 'space', 'spark', 'spatial', 'spring', 'spring-boot', 'sql', 'sqlite', 'standard', 
    'state', 'static-analyzer', 'statistics', 'storage', 'stream', 'string', 'style', 'styled-components', 'styleguide', 'svelte', 'svg', 'swagger', 'swift', 'table', 'tailwindcss', 'task', 
    'tea', 'teanager', 'template', 'tensorflow', 'terminal', 'test', 'testing', 'text', 'text-mining', 'theme', 'threejs', 'time', 'time-series', 'time-series-analysis', 'time-series-forecasting', 
    'timeseries', 'tool', 'toolkit', 'tools', 'torch', 'transit', 'transport', 'tree', 'trends', 'ts', 'tuning', 'tutorial', 'type', 'types', 'typescript', 'typescript-definitions', 'typings', 
    'ui', 'uk', 'unicode', 'url', 'util', 'utilities', 'utility', 'utils', 'validate', 'validation', 'validator', 'vector', 'video', 'view', 'visualization', 'vue', 'vue-component', 'vue3', 
    'vuejs', 'web', 'web-components', 'web-framework', 'web3', 'webapp', 'webgl', 'webgl2', 'webpack', 'webservice', 'website', 'websocket', 'windows', 'workflow', 'wrapper', 'xarray', 'xml', 
    'yaml', 'yeoman-generator', 'yii2', 'zigbee', 'zsh','linter','bayesian','sonarqube', 'sonarqube-plugin', 'social', 'terraform', 'nginx', 'detection','tauri','repository', 'boost','privacy',
    'mqtt-client', 'julia-language', 'linter', 'mesh-generation', 'rlang', 'hardware', 'conda-forge', 'static-site-generator', 'spec', 'specification', 'cartocss', 'solver', 'evaluation', 'opengl',
    'navigation', 'iot-application', 'aframe', 'web-api', 'django-rest-framework', 'transmission', 'data-visualisation', 'streamlit', 'linear-algebra', 'streamlit-webapp', 'tutorials',
    'connector', 'oop', 'development', 'random-forest', 'machinelearning', 'heroku', 'france', 'photography', 'complex-systems', 'docusaurus', 'r-stats', 'shapefile', 'optuna', 'webxr',
    'berlin', 'pathways', 'list', 'tiles', 'hafas', 'arduino-library', 'audio-processing', 'leafletjs'
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
    keywords.select{|k,v| v > 1}.map(&:first) - ignore_words
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
    update_committers
    update_keywords_from_contributors
    update(last_synced_at: Time.now, matching_criteria: matching_criteria?)
    update_score
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
    keywords = []
    keywords += repository["topics"] if repository.present?
    keywords += packages.map{|p| p["keywords"]}.flatten if packages.present?
    self.keywords = keywords.reject(&:blank?).uniq { |keyword| keyword.downcase }.dup
    self.save
  end

  def ping
    ping_urls.each do |url|
      Faraday.get(url) rescue nil
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
    conn = Faraday.new(url: repos_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    self.repository = JSON.parse(response.body)
    self.save
  rescue
    puts "Error fetching repository for #{repository_url}"
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
    conn = Faraday.new(url: owner_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

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
    conn = Faraday.new(url: timeline_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

    response = conn.get
    return unless response.success?
    summary = JSON.parse(response.body)

    conn = Faraday.new(url: timeline_url+'?after='+1.year.ago.to_fs(:iso8601)) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

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
    conn = Faraday.new(url: packages_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end

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
    conn = Faraday.new(url: commits_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
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
    conn = Faraday.new(url: repository['manifests_url']) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
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
      conn = Faraday.new(url: dependent_repos_url)
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
    conn = Faraday.new(url: issues_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
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
    resp = Faraday.get("https://repos.ecosyste.ms/api/v1/topics/#{ERB::Util.url_encode(topic)}?per_page=100&sort=created_at&order=desc")
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
    resp = Faraday.get("https://packages.ecosyste.ms/api/v1/keywords/#{ERB::Util.url_encode(keyword)}?per_page=100&sort=created_at&order=desc")
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
    resp = Faraday.get("https://repos.ecosyste.ms/api/v1/hosts/#{host}/owners/#{org}/repositories?per_page=100")
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
    conn = Faraday.new(url: archive_url(citation_file_name)) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
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

  def fetch_readme
    if readme_file_name.blank? || download_url.blank?
      fetch_readme_fallback
    else
      return unless download_url.present?
      conn = Faraday.new(url: archive_url(readme_file_name)) do |faraday|
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
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
    conn = Faraday.new(url: issues_api_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
    response = conn.get
    return unless response.success?
    issues_list_url = JSON.parse(response.body)['issues_url'] + '?per_page=1000&pull_request=false'
    # issues_list_url = issues_list_url + '&updated_after=' + last_synced_at.to_fs(:iso8601) if last_synced_at.present?

    conn = Faraday.new(url: issues_list_url) do |faraday|
      faraday.response :follow_redirects
      faraday.adapter Faraday.default_adapter
    end
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
    ['opencollective.com', 'ko-fi.com', 'liberapay.com', 'patreon.com', 'otechie.com', 'issuehunt.io', 
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
    commits['committers'].each do |committer|
      c = Contributor.find_or_create_by(email: committer['email'])
      if keywords.present?
        c.topics = (c.topics + keywords).uniq
      end
      
      c.categories = (c.categories + [category]).uniq if category
      c.sub_categories = (c.sub_categories + [sub_category]).uniq if sub_category
      c.reviewed_project_ids = (c.reviewed_project_ids + [id]).uniq if reviewed?
      c.reviewed_projects_count = c.reviewed_project_ids.length if reviewed?
      c.update(committer.except('count'))
    end
  end

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

    all_topics = contributors.flat_map { |c| c.topics }.reject{|t| ignored_keywords.include?(t) }
    
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
    update(keywords_from_contributors: ct.keys) if ct.present?
  end

  def self.unique_keywords_for_category(category)
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

  def self.unique_keywords_for_sub_category(subcategory)
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

  def self.all_category_keywords
    @all_category_keywords ||= Project.where.not(category: nil).pluck(:category).uniq.map do |category|
      {
        category: category,
        keywords: unique_keywords_for_category(category)
      }
    end
  end

  def self.all_sub_category_keywords
    @all_sub_category_keywords ||= Project.where.not(sub_category: nil).pluck(:sub_category).uniq.map do |subcategory|
      {
        sub_category: subcategory,
        keywords: unique_keywords_for_sub_category(subcategory)
      }
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
    sql = <<-SQL
      SELECT category, sub_category, COUNT(*)
      FROM projects
      WHERE category IS NOT NULL
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
