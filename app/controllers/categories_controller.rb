class CategoriesController < ApplicationController
  def index
    @categories = Project.category_tree
  end

  def show
    @categories = Project.category_tree
    @category = params[:id]

    category_data = @categories.find { |category| category[:category] == @category }
    raise ActiveRecord::RecordNotFound, "Category not found" unless category_data

    @sub_categories = category_data[:sub_categories]

    if params[:sub_category]
      @sub_category = params[:sub_category]
      sub_category_exists = @sub_categories.any? { |sc| sc[:sub_category] == @sub_category }
      raise ActiveRecord::RecordNotFound, "Sub-category not found" unless sub_category_exists

      project_scope = Project.where(category: @category, sub_category: @sub_category).order('score DESC')
      contributor_scope = Contributor.category(@category).sub_category(@sub_category).display.order('reviewed_projects_count DESC')
    else
      project_scope = Project.where(category: @category).order('score DESC')
      contributor_scope = Contributor.category(@category).display.order('reviewed_projects_count DESC')
    end

    @pagy, @projects = pagy(project_scope)
    @contributors_pagy, @contributors = pagy(contributor_scope)
  end
end