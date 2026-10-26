class RefreshRepositoryWorker
  include Sidekiq::Worker

  MAX_ATTEMPTS = 6

  def perform(project_id, attempt = 1)
    project = Project.find_by_id(project_id)
    return unless project

    project.fetch_repository
    return if project.repository.blank? || !project.repository_refresh_due? || attempt >= MAX_ATTEMPTS

    self.class.perform_in(1.hour, project_id, attempt + 1)
  end
end
