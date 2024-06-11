class Contributor < ApplicationRecord
  scope :with_topics, -> { where.not(topics: []) }
  scope :with_login, -> { where.not(login: nil) }

  scope :with_email, -> { where.not(email: [nil, '']) }

  scope :bot, -> { where('email LIKE ?', '%[bot]%') }
  scope :human, -> { where.not('email LIKE ?', '%[bot]%') }

  scope :with_reviewed_projects, -> { where('reviewed_projects_count > 0') }

  scope :valid_email, -> { where('email like ?', '%@%') }

  scope :display, -> { valid_email.ignored_emails.human.with_reviewed_projects }

  scope :ignored_emails, -> { where.not(email: IGNORED_EMAILS) }

  IGNORED_EMAILS = ['badger@gitter.im', 'you@example.com', 'actions@github.com', 'badger@codacy.com', 'snyk-bot@snyk.io',
  'dependabot[bot]@users.noreply.github.com', 'renovate[bot]@app.renovatebot.com', 'dependabot-preview[bot]@users.noreply.github.com',
  'myrmecocystus+ropenscibot@gmail.com', 'support@dependabot.com', 'action@github.com', 'support@stickler-ci.com',
  'github-bot@pyup.io', 'iron@waffle.io', 'ImgBotHelp@gmail.com', 'compathelper_noreply@julialang.org'].freeze

  def to_s
    name.presence || login.presence || email
  end

  def topics_without_ignored
    topics - Project.ignore_words
  end
end
