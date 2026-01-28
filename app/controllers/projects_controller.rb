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
    @scope = Project.search(params[:q])
    @scope = @scope.keyword(params[:keywords]) if params[:keywords].present?
    @scope = @scope.language(params[:language]) if params[:language].present?

    @facets = Project.facets(@scope)
    @pagy, @projects = pagy(@scope, limit: 20)
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
    # Use existing Dependency table instead of loading all projects
    @dependency_records = Dependency.where('count > 1').includes(:project).order('count DESC')

    # If we need fresh calculation, use find_each to avoid loading all at once
    if @dependency_records.empty?
      dependency_counts = Hash.new(0)
      Project.reviewed.find_each(batch_size: 100) do |project|
        project.dependency_packages.each do |dep|
          dependency_counts[dep] += 1
        end
      end
      @dependencies = dependency_counts.sort_by { |k,v| -v }.first(500)
    else
      @dependencies = []
    end

    @packages = []
  end

  def packages
    # Use database query instead of loading all projects into memory
    # Select only needed columns to reduce memory usage
    @projects = Project.reviewed
                       .where.not(packages: [nil, []])
                       .select(:id, :name, :url, :packages, :score, :repository, :description,
                               :keywords, :category, :sub_category, :last_synced_at)
                       .limit(500)
                       .to_a
                       .select { |p| p.packages.present? }
                       .sort_by { |p| p.packages.sum { |pkg| pkg['downloads'] || 0 } }
                       .reverse
  end

  def images
    # Use SQL pattern matching instead of loading all readmes
    @projects = Project.reviewed
                       .with_readme
                       .where("readme ~ ?", '!\\[.*?\\]\\(')
                       .select(:id, :name, :url, :readme, :repository)
                       .limit(500)
  end

  def zenodo
    # Use SQL pattern matching for zenodo
    projects = Project.reviewed
                      .with_readme
                      .where("readme ILIKE ?", '%zenodo%')
                      .select(:id, :name, :url, :readme, :repository)
                      .limit(500)
                      .to_a
                      .select { |p| p.zenodo_url.present? }
    @pagy, @projects = pagy_array(projects)
  end
end