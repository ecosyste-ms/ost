json.extract! project, :id, :name, :description, :url, :last_synced_at, :repository, :owner, :packages, :commits, :issues_stats, :events, :keywords, :dependencies, :score, :created_at, :updated_at, :avatar_url, :language, :category, :sub_category, :monthly_downloads, :total_dependent_repos, :total_dependent_packages, :readme, :funding_links, :readme_doi_urls, :works, :citation_counts, :total_citations, :keywords_from_contributors
json.project_url api_v1_project_url(project, format: :json)
json.html_url project_url(project)
