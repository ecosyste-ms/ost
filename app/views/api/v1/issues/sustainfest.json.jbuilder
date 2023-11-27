json.array! @projects do |project|
  json.partial! 'api/v1/projects/project', project: project
  json.issues project.sustainfest_issues do |issue|
    json.partial! 'api/v1/issues/issue', issue: issue
  end
end