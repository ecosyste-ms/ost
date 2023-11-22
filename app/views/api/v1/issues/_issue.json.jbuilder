json.extract! issue, :uuid, :node_id, :number, :state, :title, :user, :labels, :assignees, :locked, :comments_count, :pull_request, :closed_at, :author_association, :state_reason, :created_at, :updated_at, :time_to_close, :merged_at, :dependency_metadata, :url, :html_url
json.project do
  json.partial! 'api/v1/projects/project', project: issue.project
end