class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
  end

  def index
    @scope = Project.reviewed

    if params[:sort]
      @scope = @scope.order("#{params[:sort]} #{params[:order]}")
    else
      @scope = @scope.order('last_synced_at DESC nulls last')
    end


    @pagy, @projects = pagy(@scope)
  end

  def lookup
    @project = Project.find_by(url: params[:url])
    if @project.nil?
      @project = Project.create(url: params[:url])
      @project.sync_async
    end
    redirect_to @project
  end

  def review
    @scope = Project.unreviewed.matching_criteria

    if params[:sort]
      @scope = @scope.order("#{params[:sort]} #{params[:order]}")
    else
      @scope = @scope.order('vote_count asc, vote_score desc, score DESC nulls last')
    end

    @pagy, @projects = pagy(@scope)
  end
end