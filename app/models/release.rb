class Release < ApplicationRecord
  LOCALLY_MANAGED_ATTRIBUTES = %w[id project_id created_at updated_at].freeze

  belongs_to :project

  def self.sync_attributes(attributes)
    attributes.stringify_keys.slice(*(attribute_names - LOCALLY_MANAGED_ATTRIBUTES))
  end
end
