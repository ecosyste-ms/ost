class IssuesController < ApplicationController
  def index
    scope = Issue.good_first_issue.joins(:project).where(projects: { reviewed: true }).includes(:project)

    # Apply filters if provided
    scope = scope.joins(:project).where(projects: { category: params[:category] }) if params[:category].present?
    scope = scope.joins(:project).merge(Project.language(params[:language])) if params[:language].present?
    scope = scope.joins(:project).merge(Project.keyword(params[:keyword])) if params[:keyword].present?

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
end