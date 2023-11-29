class IssuesController < ApplicationController
  def index
    scope = Issue.good_first_issue.joins(:project).where(projects: { reviewed: true }).includes(:project)

    if params[:sort].present? || params[:order].present?
      sort = params[:sort].presence || 'issues.created_at'
      if params[:order] == 'asc'
        scope = scope.order(Arel.sql(sort).asc.nulls_last)
      else
        scope = scope.order(Arel.sql(sort).desc.nulls_last)
      end
    else
      scope = scope.order('issues.created_at DESC')
    end

    @pagy, @issues = pagy(scope)
  end
end
