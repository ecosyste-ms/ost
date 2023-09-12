class Collection < ApplicationRecord
  validates :name, :url, presence: true

  has_many :projects

  def to_s
    name
  end

  def keywords
    projects.pluck(:keywords).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def committers
    projects.map(&:committers_names).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def committer_details
    committers = {}
    projects.each do |project|
      project.raw_committers.each do |committer|

        if committer['email'].match('@users.noreply.github.com') && !committer['email'].include?('[bot]')
          committer['login'] = committer['email'].gsub('@users.noreply.github.com', '').split('+').last
        end

        committer['bot'] = committer['name'].include?('[bot]') || committer['name'].downcase.ends_with?('bot') || committer['name'].downcase == 'github actions'

        committers[committer['name'].downcase] ||= committer
        committers[committer['name'].downcase]['login'] ||= committer['login']
        committers[committer['name'].downcase]['count'] ||= 0
        committers[committer['name'].downcase]['count'] += committer['count']
        committers[committer['name'].downcase]['projects'] ||= {}
        committers[committer['name'].downcase]['projects'][project.url] ||= 0
        committers[committer['name'].downcase]['projects'][project.url] += committer['count']
      end
    end
    committers.values.sort_by{|c| c['projects'].length}.reverse
  end

  def languages
    projects.map(&:language).flatten.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def commits
    hash = Hash.new{|h,k| h[k] = 0}
    projects.map(&:committers).each do |committers|
      committers.each do |k,v|
        hash[k] += v
      end
    end
    hash.sort_by{|k,v| v}.reverse
  end

  def committers_projects(name)
    projects.select{|p| p.committers_names.include?(name) }
  end

  def dependencies
    deps = projects.map(&:dependency_packages).flatten(1)
    deps.group_by(&:itself).transform_values(&:count).sort_by{|k,v| v}.reverse
  end

  def dependency_projects(dependency)
    projects.select{|p| p.dependency_packages.include?(dependency.split(':')) }
  end

  def import_keyword(keyword)
    resp = Faraday.get("https://packages.ecosyste.ms/api/v1/keywords/#{keyword}?per_page=1000")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data['packages'].reject{|p| p['status'].present? }.map{|p| p['repository_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = projects.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
      end
    end
  end

  def import_topic(topic)
    resp = Faraday.get("https://repos.ecosyste.ms/api/v1/topics/#{topic}?per_page=1000")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data['repositories'].map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = projects.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
      end
    end
  end

  def import_org(host, org)
    resp = Faraday.get("https://repos.ecosyste.ms/api/v1/hosts/#{host}/owners/#{org}/repositories?per_page=1000")
    if resp.status == 200
      data = JSON.parse(resp.body)
      urls = data.map{|p| p['html_url'] }.uniq.reject(&:blank?)
      urls.each do |url|
        puts url
        project = projects.find_or_create_by(url: url)
        project.sync_async unless project.last_synced_at.present?
      end
    end
  end

  def import_tag(tag)
    import_keyword(tag)
    import_topic(tag)
  end

  def remove_duplicate_projects
    projects.group_by(&:url).each do |url, projects|
      projects[1..-1].each(&:destroy)
    end
    return nil
  end

  def remove_uninteresting_forks
    projects.each do |project|
      if project.repository.present? && project.repository['source_name'].present? && project.repository['stargazers_count'] == 0
        puts "Removing #{project.url}"
        project.destroy
      end
    end
    return nil
  end
end
