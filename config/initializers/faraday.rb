require 'faraday/typhoeus'
Faraday.default_adapter = :typhoeus

Faraday.default_connection_options = {
  headers: {
    'User-Agent' => 'ost.ecosyste.ms'
  }
}
