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
    end

    @pagy, @projects = pagy_countless(@projects)
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
    # Use database query instead of loading all projects
    @projects = Project.reviewed
                       .active
                       .where.not(packages: [nil, []])
                       .select(:id, :name, :url, :packages, :score, :repository)
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
                       .includes(:climatetriage_issues)
                       .limit(500)
  end

  def esd
    @projects = Project.all.where.not(last_synced_at: nil).where(esd: true)

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'projects.updated_at'
      if params[:order] == 'asc'
        @projects = @projects.order(Arel.sql(sort).asc.nulls_last)
      else
        @projects = @projects.order(Arel.sql(sort).desc.nulls_last)
      end
    end

    @pagy, @projects = pagy_countless(@projects)
    render :index
  end

  def search
    filters = []
    filters << "keywords = \"#{params[:keywords]}\"" if params[:keywords].present?
    filters << "language = \"#{params[:language]}\"" if params[:language].present?

    filter_string = filters.join(" AND ") if filters.any?

    @projects = Project.pagy_search(params[:q], facets: ['keywords', 'language'], filter: filter_string)
    @pagy, @projects = pagy_meilisearch(@projects, limit: 20)
  end

  def dependencies
    # Use existing Dependency table or calculate with find_each
    dependency_records = Dependency.where('count > 1').includes(:project)

    if dependency_records.any?
      # Use cached dependency data, filter out python and r
      all_dependencies = dependency_records.reject { |dep| ['python', 'r'].include?(dep.ecosystem) }

      @dependencies = all_dependencies.map do |dep|
        {
          ecosystem: dep.ecosystem,
          package_name: dep.name,
          count: dep.count,
          in_ost: dep.project&.reviewed? || false
        }
      end.sort_by { |d| -d[:count] }
    else
      # Calculate with find_each to avoid loading all projects
      dependency_counts = Hash.new(0)
      Project.reviewed.find_each(batch_size: 100) do |project|
        project.dependency_packages.each do |dep|
          dependency_counts[dep] += 1
        end
      end

      # Filter out python and r packages
      filtered_dependencies = dependency_counts.reject { |dep, count| ['python', 'r'].include?(dep[0]) }

      @dependencies = filtered_dependencies.sort_by { |k,v| -v }.map do |dep, count|
        package = dependency_records.find { |p| p.ecosystem == dep[0] && p.name == dep[1] }
        {
          ecosystem: dep[0],
          package_name: dep[1],
          count: count,
          in_ost: package&.project&.reviewed? || false
        }
      end
    end

    # Paginate with pagy_array
    items_per_page = params[:per_page]&.to_i || 100
    @pagy, @dependencies = pagy_array(@dependencies, items: items_per_page)
  end
end