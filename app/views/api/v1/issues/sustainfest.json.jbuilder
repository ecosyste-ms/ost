json.array! @projects do |project, issues|
  json.partial! 'api/v1/projects/project', project: project
  json.issues issues do |issue|
    json.partial! 'api/v1/issues/issue', issue: issue
  end
end