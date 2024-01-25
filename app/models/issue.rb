class Issue < ApplicationRecord
  belongs_to :project

  CLIMATETRIAGE_LABELS = [":beginner: good first issue",
  ":open_hands: help wanted",
  "Good First Issue",
  "Good as first PR",
  "Good first issue",
  "Hacktoberfest",
  "Help Text",
  "Help Wanted",
  "Help needed",
  "Help wanted",
  "Misc: good first issue",
  "contrib-good-first-issue",
  "contrib-help-wanted",
  "first-good-issue",
  "good first contribution",
  "good first issue",
  "good first issue :heart:",
  "good first issue :star:",
  "good first issue 🐤",
  "good first issue 🐾",
  "good first review",
  "good for beginners",
  "good for new contributors",
  "good-first-issue",
  "good_for_beginners",
  "hacktoberfest",
  "help",
  "help needed",
  "help wanted",
  "help wanted 🆘",
  "help wanted 🖐",
  "help wanted 🦮",
  "help wanted!",
  "help-wanted",
  "i-good-first-issue",
  "issue type: good first issue",
  "open climate action",
  "question & help wanted",
  "status --- good first issue",
  "status --- help wanted :heart:",
  "status: good first issue",
  "status: help wanted",
  "status: needs help",
  "tag:help-wanted",
  "🏁 Good first issue",
  "🏄‍♂️ good first issue",
  "🛟 help wanted"]

  scope :label, ->(labels) { where("labels && ARRAY[?]::varchar[]", labels) }
  scope :climatetriage, -> { label(CLIMATETRIAGE_LABELS) }
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
