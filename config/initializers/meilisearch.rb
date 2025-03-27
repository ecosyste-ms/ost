url = URI.parse(ENV.fetch('MEILISEARCH_URL', 'http://localhost:7700'))
api_key = url.password
url_without_password = "#{url.scheme}://#{url.host}:#{url.port}"

Meilisearch::Rails.configuration = {
  meilisearch_url: url_without_password,
  meilisearch_api_key: api_key,
  timeout: 10
}