class Contributor < ApplicationRecord
  scope :with_topics, -> { where.not(topics: []) }
  scope :with_login, -> { where.not(login: nil) }
end
