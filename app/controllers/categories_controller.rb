class CategoriesController < ApplicationController
  def index
    @categories = Project.category_tree
  end

  def show
    @categories = Project.category_tree
    @category = params[:id]
    if params[:sub_category]  
      @sub_category = params[:sub_category]
      project_scope = Project.where(category: @category, sub_category: @sub_category).reviewed
      contributor_scope = Contributor.category(@category).sub_category(@sub_category).display.order('reviewed_projects_count DESC')
    else
      project_scope = Project.where(category: @category).reviewed
      contributor_scope = Contributor.category(@category).display.order('reviewed_projects_count DESC')
    end
    @sub_categories = @categories.find { |category| category[:category] == @category }[:sub_categories]
    
    @pagy, @projects = pagy(project_scope)
    @contributors_pagy, @contributors = pagy(contributor_scope)
  end
end