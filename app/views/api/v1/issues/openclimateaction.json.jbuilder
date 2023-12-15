json.array! @projects do |project|
  json.extract! project, :id, :name, :description, :url, :last_synced_at, :repository, :created_at, :updated_at, :avatar_url, :category, :sub_category
  json.language project.language_with_default
  json.has_new_issues project.openclimateaction_issues.any?{|issue| issue.created_at > 7.days.ago}
  json.issues project.openclimateaction_issues do |issue|
    json.extract! issue, :uuid, :number, :title, :labels, :comments_count, :created_at, :updated_at, :html_url, :monthly_downloads
  end
end