class Api::V1::IssuesController < Api::V1::ApplicationController
  def index
    scope = Issue.where(pull_request: false, state: 'open').includes(:project)
    scope = scope.joins(:project).where(projects: { reviewed: true }).climatetriage.good_first_issue

    # Apply filters if provided
    scope = scope.joins(:project).where(projects: { category: params[:category] }) if params[:category].present?
    scope = scope.joins(:project).merge(Project.language(params[:language])) if params[:language].present?
    scope = scope.joins(:project).merge(Project.keyword(params[:keyword])) if params[:keyword].present?

    scope = scope.where('issues.created_at > ?', 1.day.ago) if params[:recent].present?

    if params[:sort].present? || params[:order].present?
      sort = sanitize_sort(Issue.sortable_columns, default: 'created_at')
      if params[:order] == 'asc'
        scope = scope.order(sort.asc.nulls_last)
      else
        scope = scope.order(sort.desc.nulls_last)
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
      sort = sanitize_sort(Project.sortable_columns, default: 'projects.updated_at')
      if params[:order] == 'asc'
        scope = scope.order(sort.asc.nulls_last)
      else
        scope = scope.order(sort.desc.nulls_last)
      end
    else
      scope = scope.order('projects.updated_at DESC')
    end

    @pagy, @projects = pagy(scope)
  end

  def climatetriage_counts
    scope = Issue.where(pull_request: false)
    scope = scope.joins(:project).where(projects: { reviewed: true }).climatetriage.good_first_issue

    scope = scope.joins(:project).where(projects: { category: params[:category] }) if params[:category].present?
    scope = scope.joins(:project).merge(Project.language(params[:language])) if params[:language].present?
    scope = scope.joins(:project).merge(Project.keyword(params[:keyword])) if params[:keyword].present?

    json = {
      opened_count: scope.where('issues.created_at > ?', 1.month.ago).count,
      closed_count: scope.where('issues.closed_at > ?', 1.month.ago).count,
      opened_histogram: scope.where('issues.created_at > ?', 1.month.ago).group_by_day(:created_at).count,
      closed_histogram: scope.where('issues.closed_at > ?', 1.month.ago).group_by_day(:closed_at).count,
    }

    render json: json
  end
end