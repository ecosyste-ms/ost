class Issue < ApplicationRecord
  belongs_to :project

  scope :label, ->(labels) { where("labels && ARRAY[?]::varchar[]", labels) }
  scope :climatetriage, -> { label(["open climate action", 'help wanted', 'good first issue', 'Good First Issue','hacktoberfest', 'Hacktoberfest', 'good-first-issue', 'contrib-good-first-issue', 'first-good-issue']) }
  scope :good_first_issue, -> { climatetriage.where(pull_request: false, state: 'open').where('issues.updated_at > ?', 2.years.ago)  }

  def old_labels
    JSON.parse(labels_raw)
  end

  def labels
    self[:labels].presence || old_labels
  end

  def update_labels
    update(labels: old_labels) if old_labels.present?
  end
end
