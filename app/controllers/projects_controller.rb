class ProjectsController < ApplicationController
  def show
    @project = Project.find(params[:id])
  end

  def index
    @scope = Project.reviewed

    if params[:keyword].present?
      @scope = @scope.keyword(params[:keyword])
    end

    if params[:owner].present?
      @scope = @scope.owner(params[:owner])
    end

    if params[:language].present?
      @scope = @scope.language(params[:language])
    end

    if params[:sort]
      @scope = @scope.order("#{params[:sort]} #{params[:order]}")
    else
      @scope = @scope.order('last_synced_at DESC nulls last')
    end

    @pagy, @projects = pagy(@scope)
  end

  def lookup
    @project = Project.find_by(url: params[:url].downcase)
    if @project.nil?
      @project = Project.create(url: params[:url].downcase)
      @project.sync_async
    end
    redirect_to @project
  end

  def review
    @scope = Project.unreviewed.matching_criteria.where('vote_score > ?', -2).includes(:votes)

    if params[:keyword].present?
      @scope = @scope.keyword(params[:keyword])
    end

    if params[:owner].present?
      @scope = @scope.owner(params[:owner])
    end

    if params[:language].present?
      @scope = @scope.language(params[:language])
    end

    if params[:sort]
      @scope = @scope.order("#{params[:sort]} #{params[:order]}")
    else
      @scope = @scope.order('vote_count asc, vote_score desc, score DESC nulls last')
    end

    @pagy, @projects = pagy(@scope)
  end

  def new
    @project = Project.new
  end

  def create
    @project = Project.new(project_params)
    if @project.valid?
      @project = Project.find_by(url: params[:project][:url].downcase)
      if @project.nil?

        @project = Project.new(project_params)

        if @project.save
          @project.sync_async
          redirect_to @project
        else
          render 'new'
        end
      else
        redirect_to @project
      end
    else
      render 'new'
    end
  end

  def project_params
    params.require(:project).permit(:url, :name, :description)
  end
end