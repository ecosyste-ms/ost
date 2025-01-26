namespace :search do
  desc "Reindex all searchable models"
  task reindex: :environment do
    Project.clear_index!(true)
    Project.reviewed.find_each(&:index!)
  end
end