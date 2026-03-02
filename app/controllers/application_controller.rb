class ApplicationController < ActionController::Base
  skip_forgery_protection
  include Pagy::Backend

  before_action :set_cache_headers

  def default_url_options(options = {})
    Rails.env.production? ? { :protocol => "https" }.merge(options) : options
  end

  def sanitize_sort(allowed_columns, default: 'updated_at')
    sort_param = params[:sort].presence || default
    sql = allowed_columns[sort_param] || allowed_columns[default] || default
    Arel.sql(sql)
  end

  def set_cache_headers(browser_ttl: 5.minutes, cdn_ttl: 6.hours)
    return unless request.get?
    response.headers['Cache-Control'] = "public, max-age=#{browser_ttl.to_i}, s-maxage=#{cdn_ttl.to_i}, stale-while-revalidate=#{cdn_ttl.to_i}, stale-if-error=#{1.day.to_i}"
  end
end
