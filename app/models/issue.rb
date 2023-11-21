class Issue < ApplicationRecord
  belongs_to :project

  def labels
    JSON.parse(self[:labels])
  end
end
