json.array! @projects do |project|
  json.extract! project, :id, :name, :description, :url, :last_synced_at, :repository, :created_at, :updated_at, :avatar_url, :language, :category, :sub_category
  json.has_new_issues project.openclimateaction_issues.any?{|issue| issue.created_at > 7.days.ago}
  json.issues project.openclimateaction_issues do |issue|
    json.extract! issue, :uuid, :number, :title, :labels, :comments_count, :created_at, :updated_at, :html_url
  end
end