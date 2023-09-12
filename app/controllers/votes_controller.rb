class VotesController < ApplicationController
  def create
    @project = Project.find(params[:project_id])
    @vote = @project.votes.new(vote_params)
    @vote.save
    redirect_back fallback_location: review_projects_path
  end

  def vote_params
    params.require(:vote).permit(:score)
  end
end