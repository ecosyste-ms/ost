class ReleasesController < ApplicationController
  def index
    @releases = Release.all.order('published_at DESC')

    if params[:project_id]
      @project = Project.find(params[:project_id])
      @releases = @releases.where(project_id: params[:project_id])
    end

    @pagy, @releases = pagy_countless(@releases)
  end

  def show
    @release = Release.find(params[:id])
  end
end