json.extract! collection, :id, :name, :description, :url, :projects_count, :created_at, :updated_at
json.collection_url api_v1_collection_url(collection, format: :json)
json.projects_url projects_api_v1_collection_url(collection, format: :json)
json.html_url collection_url(collection)