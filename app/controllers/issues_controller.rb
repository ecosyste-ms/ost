class IssuesController < ApplicationController
  def index
    scope = Issue.good_first_issue.joins(:project).where(projects: { reviewed: true }).includes(:project)

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
end