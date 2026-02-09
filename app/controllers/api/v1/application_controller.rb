class Api::V1::ApplicationController < ApplicationController
  before_action :set_api_cache_headers
  after_action { pagy_headers_merge(@pagy) if @pagy }

  def set_api_cache_headers
    set_cache_headers(cdn_ttl: 1.hour)
  end
end