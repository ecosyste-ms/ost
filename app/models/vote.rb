class Vote < ApplicationRecord
  belongs_to :project

  after_create :update_project_vote_count

  def update_project_vote_count
    project.update_vote_count
  end
end
