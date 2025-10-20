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
      if params[:order] == 'asc'
        @scope = @scope.order(Arel.sql(params[:sort]).asc.nulls_last)
      else
        @scope = @scope.order(Arel.sql(params[:sort]).desc.nulls_last)
      end
    else
      @scope = @scope.order(Arel.sql('score').desc.nulls_last)
    end

    @pagy, @projects = pagy(@scope)
  end

  def search
    filters = []
    filters << "keywords = \"#{params[:keywords]}\"" if params[:keywords].present?
    filters << "language = \"#{params[:language]}\"" if params[:language].present?
  
    filter_string = filters.join(" AND ") if filters.any?
  
    @projects = Project.pagy_search(params[:q], facets: ['keywords', 'language'], filter: filter_string)
    @pagy, @projects = pagy_meilisearch(@projects, limit: 20)
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
      if params[:order] == 'asc'
        @scope = @scope.order(Arel.sql(params[:sort]).asc.nulls_last)
      else
        @scope = @scope.order(Arel.sql(params[:sort]).desc.nulls_last)
      end
    else
      @scope = @scope.order('vote_count asc, vote_score desc, created_at DESC')
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

  def dependencies
    @dependencies = Project.reviewed.map(&:dependency_packages).flatten(1).group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
    @dependency_records = Dependency.where('count > 1').includes(:project)
    @packages = []
  end

  def packages
    @projects = Project.reviewed.select{|p| p.packages.present? }.sort_by{|p| p.packages.sum{|p| p['downloads'] || 0 } }.reverse
  end

  def images
    @projects = Project.reviewed.with_readme.select{|p| p.readme_image_urls.present? }
  end

  def zenodo
    projects = Project.reviewed.with_readme.select{|p| p.zenodo_url.present? }
    @pagy, @projects = pagy_array(projects)
  end
end