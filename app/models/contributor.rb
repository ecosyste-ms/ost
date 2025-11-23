class Contributor < ApplicationRecord
  include EcosystemApiClient
  scope :with_topics, -> { where.not(topics: []) }
  scope :with_login, -> { where.not(login: nil) }
  scope :with_email, -> { where.not(email: [nil, '']) }
  scope :with_profile, -> { where("profile::text != '{}'") }

  scope :bot, -> { where('email ILIKE ? OR login ILIKE ?', '%[bot]%', '%-bot') }
  scope :human, -> { where.not('email ILIKE ?', '%[bot]%') }

  scope :with_reviewed_projects, -> { where('reviewed_projects_count > 0') }

  scope :valid_email, -> { where('email like ?', '%@%') }

  scope :display, -> { valid_email.ignored_emails.human.with_reviewed_projects }

  scope :with_funding_links, -> { where("LENGTH(profile ->> 'funding_links') > 2") }

  scope :ignored_emails, -> { where.not(email: IGNORED_EMAILS) }

  scope :category, ->(category) { where("categories @> ARRAY[?]::varchar[]", category) }
  scope :sub_category, ->(sub_category) { where("sub_categories @> ARRAY[?]::varchar[]", sub_category) }

  IGNORED_EMAILS = ['badger@gitter.im', 'you@example.com', 'actions@github.com', 'badger@codacy.com', 'snyk-bot@snyk.io',
  'dependabot[bot]@users.noreply.github.com', 'renovate[bot]@app.renovatebot.com', 'dependabot-preview[bot]@users.noreply.github.com',
  'myrmecocystus+ropenscibot@gmail.com', 'support@dependabot.com', 'action@github.com', 'support@stickler-ci.com',
  'github-bot@pyup.io', 'iron@waffle.io', 'ImgBotHelp@gmail.com', 'compathelper_noreply@julialang.org','bot@deepsource.io',
  'badges@fossa.io', 'github-actions@github.com', 'bot@stepsecurity.io',
  '49699333+dependabot[bot]@users.noreply.github.com',
  '41898282+github-actions[bot]@users.noreply.github.com',
  '66853113+pre-commit-ci[bot]@users.noreply.github.com',
  '46447321+allcontributors[bot]@users.noreply.github.com'
].freeze

  def topics
    # Sanitize null bytes from topics array on read
    super&.map { |t| t.gsub(/\u0000/, '') }&.reject(&:blank?) || []
  end

  def to_s
    name.presence || login.presence || email
  end

  def self.bot_email?(email)
    return false if email.blank?
    email_lower = email.to_s.downcase

    return true if IGNORED_EMAILS.include?(email_lower)
    return true if email_lower.include?('[bot]')
    return true if email_lower.include?('bot@')
    return true if email_lower =~ /^\d+\+.+\[bot\]@users\.noreply\.github\.com$/

    false
  end

  def bot?
    self.class.bot_email?(email)
  end

  def topics_without_ignored
    topics - Project.ignore_words
  end

  def reviewed_projects
    Project.where(id: reviewed_project_ids).reviewed.order('score DESC')
  end

  def ping
    return unless ping_urls
    self.class.ecosystem_http_get(ping_urls)
  end

  def repos_api_url
    return nil if login.blank?
    "https://repos.ecosyste.ms/api/v1/hosts/Github/owners/#{login}"
  end

  def ping_urls
    repos_api_url + '/ping' if repos_api_url
  end

  def fetch_profile
    return if repos_api_url.blank?
    
    response = self.class.ecosystem_http_get(repos_api_url)
    return unless response.success?

    profile = JSON.parse(response.body)
    update(profile: profile, last_synced_at: Time.now)
  end

  def import_repos
    return if repos_api_url.blank?

    response = self.class.ecosystem_http_get("#{repos_api_url}/repositories?per_page=1000")
    return unless response.success?

    repos = JSON.parse(response.body)
    repos.each do |repo|
      next if repo['archived'] || repo['fork'] || repo['private'] || repo['template']
      
      project = Project.find_or_create_by(url: repo['html_url'])
      project.sync_async unless project.last_synced_at.present?
    end
  end

  def owned_projects
    Project.owner(login)
  end
end
