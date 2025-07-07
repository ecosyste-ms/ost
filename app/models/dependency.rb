class Dependency < ApplicationRecord
  include EcosystemApiClient
  
  belongs_to :project, optional: true

  def sync_package
    
    purl = "https://packages.ecosyste.ms/api/v1/packages/lookup?ecosystem=#{ecosystem}&name=#{name}"
      
    puts "  Fetching #{purl}"
    
    conn = ecosystem_http_client(purl)

    response = conn.get
    puts "  Response: #{response.status}"
    return unless response.success?
    packages = JSON.parse(response.body)
    package = packages.first
    return unless package.present?
    puts " #{package['repository_url']}"
    project = Project.find_or_create_by(url: package['repository_url'])
    project.sync if project.last_synced_at.nil? 

    update(package: package, repository_url: package['repository_url'], project_id: project.id, average_ranking: package['rankings']['average'])
  end
end
