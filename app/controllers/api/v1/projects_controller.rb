class Api::V1::ProjectsController < Api::V1::ApplicationController
  def index
    @projects = Project.all.where.not(last_synced_at: nil)
    @pagy, @projects = pagy(@projects)
  end

  def show
    @project = Project.find(params[:id])
  end

  def lookup
    @project = Project.find_by(url: params[:url])
    if @project.nil?
      @project = Project.create(url: params[:url])
      @project.sync_async
    end
    @project.sync_async if @project.last_synced_at.nil? || @project.last_synced_at < 1.day.ago
  end

  def ping
    @project = Project.find(params[:id])
    @project.sync_async
    render json: { message: 'pong' }
  end
end