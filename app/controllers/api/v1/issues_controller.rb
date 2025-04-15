class Api::V1::IssuesController < Api::V1::ApplicationController
  def index
    scope = Issue.where(pull_request: false, state: 'open').includes(:project)
    scope = scope.joins(:project).where(projects: { reviewed: true }).climatetriage.good_first_issue

    # Apply filters if provided
    scope = scope.joins(:project).where(projects: { category: params[:category] }) if params[:category].present?
    scope = scope.joins(:project).merge(Project.language(params[:language])) if params[:language].present?
    scope = scope.joins(:project).merge(Project.keyword(params[:keyword])) if params[:keyword].present?

    # Define allowed sort fields with database expressions
    allowed_sort_fields = {
      'created_at' => 'issues.created_at',
      'updated_at' => 'issues.updated_at',
      'stars' => "CAST(projects.repository->>'stargazers_count' AS INTEGER)"
    }

    if params[:sort].present? || params[:order].present?
      sort_key = params[:sort].presence || 'created_at'
      sort_field = allowed_sort_fields[sort_key] || 'issues.created_at'
      
      if params[:order] == 'asc'
        scope = scope.order(Arel.sql(sort_field).asc.nulls_last)
      else
        scope = scope.order(Arel.sql(sort_field).desc.nulls_last)
      end
    else
      scope = scope.order('issues.created_at DESC')
    end

    @pagy, @issues = pagy(scope)
  end

  def openclimateaction
    project_ids = Issue.good_first_issue.pluck(:project_id).uniq

    scope = Project.where(id: project_ids).active.reviewed.includes(:climatetriage_issues)

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'projects.updated_at'
      if params[:order] == 'asc'
        scope = scope.order(Arel.sql(sort).asc.nulls_last)
      else
        scope = scope.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      scope = scope.order('projects.updated_at DESC')
    end

    @pagy, @projects = pagy(scope)
  end

  def climatetriage_counts
    scope = Issue.where(pull_request: false)
    scope = scope.joins(:project).where(projects: { reviewed: true }).climatetriage.good_first_issue

    scope = scope.where('issues.created_at > ?', 1.month.ago)

    scope = scope.joins(:project).where(projects: { category: params[:category] }) if params[:category].present?
    scope = scope.joins(:project).merge(Project.language(params[:language])) if params[:language].present?
    scope = scope.joins(:project).merge(Project.keyword(params[:keyword])) if params[:keyword].present?

    json = {
      opened: scope.count,
      closed: scope.closed.count,
    }

    render json: json
  end
end