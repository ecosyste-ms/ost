require 'csv'

namespace :projects do
  desc 'sync projects'
  task :sync => :environment do
    Project.sync_least_recently_synced
  end

  desc 'sync reviewed projects'
  task :sync_reviewed => :environment do
    Project.sync_least_recently_synced_reviewed
  end

  desc 'import projects'
  task :import => :environment do
    Project.import_from_readme
    Project.import_education
  end

  desc 'discover projects'
  task :discover => :environment do
    Project.discover_via_topics
    Project.discover_via_keywords
  end

  desc 'sync dependencies'
  task :sync_dependencies => :environment do
    Project.sync_dependencies
  end

  desc 'import projects from JOSS (Journal of Open Source Software)'
  task :import_joss => :environment do
    Project.import_from_joss
  end
end