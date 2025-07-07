module EcosystemApiClient
  extend ActiveSupport::Concern

  included do
    def ecosystem_http_client(url)
      Faraday.new(url: url) do |faraday|
        faraday.headers['User-Agent'] = 'ost.ecosyste.ms'
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
    end
  end

  class_methods do
    def ecosystem_http_get(url)
      conn = Faraday.new(url: url) do |faraday|
        faraday.headers['User-Agent'] = 'ost.ecosyste.ms'
        faraday.response :follow_redirects
        faraday.adapter Faraday.default_adapter
      end
      conn.get
    end
  end
end