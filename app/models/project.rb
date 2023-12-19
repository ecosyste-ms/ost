require 'csv'

class Project < ApplicationRecord

  validates :url, presence: true, uniqueness: { case_sensitive: false }

  has_many :votes, dependent: :delete_all
  has_many :issues, dependent: :delete_all

  has_many :openclimateaction_issues, -> { good_first_issue }, class_name: 'Issue'

  scope :active, -> { where("(repository ->> 'archived') = ?", 'false') }
  scope :archived, -> { where("(repository ->> 'archived') = ?", 'true') }

  scope :language, ->(language) { where("(repository ->> 'language') = ?", language) }
  scope :owner, ->(owner) { where("(repository ->> 'owner') = ?", owner) }
  scope :keyword, ->(keyword) { where("keywords @> ARRAY[?]::varchar[]", keyword) }
  scope :reviewed, -> { where(reviewed: true) }
  scope :unreviewed, -> { where(reviewed: nil) }
  scope :matching_criteria, -> { where(matching_criteria: true) }
  scope :with_readme, -> { where.not(readme: nil) }

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

          project = Project.find_or_create_by(url: )
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
    ['hacktoberfest', 'python', 'java', "open-data", "open-source", 'network', 'r', 'database', 'ruby', 'iot', 'julia', 'numpy', 'pandas', 'rstats', 'react','python3','env', 'map', 'api', 'cran',
     'awesome','data','dataset','awesome-list', 'javascript','r-package','raspberry-pi','matlab', 'typescript', 'svelte', 'nodejs', 'c', 'fortran', 'modbus','matplotlib',
     'sqlite','arduino','golang','influxdb','esp8266','laravel','gui','smart-meter','docker','dashboard','platform','building','geospatial','pytorch','deep-learning','documentation', 'gis','remote-sensing',
     'machine-learning', 'satellite','xarray','google-earth-engine','earth-engine','linear-programming','management','netcdf','sql','3d','rstudio','firebase','webgl','flask','blockchain','addon','osm','go',
     'rust','vue','vuejs','rest-api','ios','linux','python-3','postgresql','postgis','jupyter-notebook','game','ethereum','d3','d3js','code','android','ai','library','client','django','package','energy-monitor',
    'finance', 'risk','time-series','raster','hpc','scipy','workflow','numba','nasa','cpp','cmake','c-plus-plus','analysis','data-science','plotting','iot-platform','transport','artificial-intelligence', 'aws',
     'neural-networks', 'time-series-forecasting', 'timeseries', 'torch','models','datasets','high-performance-computing', 'peer-reviewed', 'reproducible-research','websocket','fleet-management','citation', 
     'credit', 'metadata', 'standard', 'nasa-data', 'satellite-data', 'space','geographic-information-systems', 'satellite-imagery', 'satellite-images', 'energy', 'statistics','openfoodfacts','tensorflow',
     'nutrition','azure','modeling', 'tuning','iobroker','benchmark','kubernetes','k8s', 'helm', 'github-action', 'github-actions', 'svg','cnc','spark', 'scala', 'pyspark','microsoft', 'http','apache-spark',
    'hacktoberfest2020','neural-network','farm','python-library','uk','openstreetmap','robotics','mechanical-engineering','lidar','sdk','cli','gpu','ml','landsat','food','automation','gtfs','ggplot2', 'github',
    'kotlin', 'sentinel','visualization','maps','mapping','dask','pipeline','api-client','transit','education','api-wrapper','course','mapbox','engineering','atmosphere','scenario','optimization',
    'data-analysis','data-visualization','backend','model','modelling','nextjs','pyam','australia','object-detection','monte-carlo-simulation','time-series-analysis','cnn','forecasting','forecast','openai-gym',
    'rails','ruby-on-rails','science',"computer-vision","image-processing","image-classification","segmentation","spatial","classification","electricity","image-segmentation","simulation",'php','leaflet',
    'regression','vector','mobile','leaflet-plugins','sentinel-1','cpu','fastapi','zigbee','metrics','big-data','cross-platform','self-driving-car','json','computing','framework','frontend',
    'pwa','web','web-framework','react-native','analytics','electron','homeassistant','home-assistant','smarthome','home-automation','pi0']
  end

  def self.stop_words
    []
  end

  def self.update_matching_criteria
    unreviewed.find_each{|p| p.matching_criteria = p.matching_criteria?;p.save if p.changed?}
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
    Project.reviewed.where(last_synced_at: nil).or(Project.where("last_synced_at < ?", 1.day.ago)).order('last_synced_at asc nulls first').limit(500).each do |project|
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
    self.keywords = keywords.uniq.reject(&:blank?)
    self.save
  end

  def ping
    ping_urls.each do |url|
      Faraday.get(url) rescue nil
    end
  end

  def ping_urls
    ([repos_ping_url] + packages_ping_urls + [owner_ping_url]).compact.uniq
  end

  def repos_ping_url
    return unless repository.present?
    "https://repos.ecosyste.ms/api/v1/hosts/#{repository['host']['name']}/repositories/#{repository['full_name']}/ping"
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
    no_bad_topics? && good_topics? && external_users? && open_source_license? && active?
  end

  def matching_topics
    (keywords & Project.relevant_keywords)
  end

  def no_bad_topics?
    (keywords & Project.stop_words).blank?
  end

  def good_topics?
    matching_topics.length > 2
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
    repository['license']
  end

  def packages_licenses
    return [] unless packages.present?
    packages.map{|p| p['license'] }.compact
  end

  def open_source_license?
    (packages_licenses + [repository_license]).compact.uniq.any?
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
    return unless readme_file_name.present?
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
    
    tokenizer = Tokenizers.from_pretrained("bert-base-cased")
    tokenizer.encode(preprocessed_readme)
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
    issues_list_url = JSON.parse(response.body)['issues_url'] + '?per_page=1000&pull_request=false&state=open'
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
      issues.find_or_create_by(number: issue['number']) do |i|
        i.assign_attributes(issue)
        i.save(touch: false)
      end
    end
  end
end
