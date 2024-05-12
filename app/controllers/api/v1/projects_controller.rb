class Api::V1::ProjectsController < Api::V1::ApplicationController
  def index
    @projects = Project.all.where.not(last_synced_at: nil)

    @projects = @projects.where(reviewed: true) if params[:reviewed] == 'true'

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'projects.updated_at'
      if params[:order] == 'asc'
        @projects = @projects.order(Arel.sql(sort).asc.nulls_last)
      else
        @projects = @projects.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      @projects = @projects.order('projects.updated_at DESC')
    end

    @pagy, @projects = pagy(@projects)
  end

  def show
    @project = Project.find(params[:id])
  end

  def lookup
    @project = Project.find_by(url: params[:url].downcase)
    if @project.nil?
      @project = Project.create(url: params[:url].downcase)
      @project.sync_async
    end
    @project.sync_async if @project.last_synced_at.nil? || @project.last_synced_at < 1.day.ago
  end

  def ping
    @project = Project.find(params[:id])
    @project.sync_async
    render json: { message: 'pong' }
  end

  def packages
    @projects = Project.reviewed.active.select{|p| p.packages.present? }.sort_by{|p| p.packages.sum{|p| p['downloads'] || 0 } }.reverse
  end

  def images
    @projects = Project.reviewed.with_readme.select{|p| p.readme_image_urls.present? }
  end
end