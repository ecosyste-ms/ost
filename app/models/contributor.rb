class Contributor < ApplicationRecord
  scope :with_topics, -> { where.not(topics: []) }
  scope :with_login, -> { where.not(login: nil) }

  scope :with_email, -> { where.not(email: [nil, '']) }

  scope :bot, -> { where('email LIKE ?', '%[bot]%') }
  scope :human, -> { where.not('email LIKE ?', '%[bot]%') }

  scope :with_reviewed_projects, -> { where('reviewed_projects_count > 0') }

  scope :valid_email, -> { where('email like ?', '%@%') }

  scope :display, -> { valid_email.human.with_reviewed_projects }

  def to_s
    name.presence || login.presence || email
  end

  def topics_without_ignored
    topics - Project.ignore_words
  end
end
