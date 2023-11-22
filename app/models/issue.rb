class Issue < ApplicationRecord
  belongs_to :project

  scope :label, ->(labels) { where("labels && ARRAY[?]::varchar[]", labels) }
  scope :sustainfest, -> { label(["sustainfest", 'help wanted', 'good first issue']) }

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
