# frozen_string_literal: true

require_relative 'config'

# nodoc
module Auth
  AUTH_URL = "id.#{Config::BASE_URL}/oauth/token"

  ACCOUNTS_SCOPES = %w[accounts:read accounts:execute].freeze
  BANKS_SCOPES = %w[banks:read banks:write].freeze
  CUSTOMERS_SCOPES = %w[customers:read customers:write customers:execute].freeze
  PRICES_SCOPES = %w[prices:read].freeze
  QUOTES_SCOPES = %w[quotes:execute].freeze
  TRADES_SCOPES = %w[trades:read trades:execute].freeze

  SCOPES = [
    *ACCOUNTS_SCOPES,
    *BANKS_SCOPES,
    *CUSTOMERS_SCOPES,
    *PRICES_SCOPES,
    *QUOTES_SCOPES,
    *TRADES_SCOPES
  ].freeze

  def self.token
    auth_headers = {
      'Content-type': 'application/json'
    }
    auth_body = {
      grant_type: 'client_credentials',
      client_id: Config::CLIENT_ID,
      client_secret: Config::CLIENT_SECRET,
      scope: SCOPES.join(' ')
    }.to_json

    response = Faraday.post("https://#{AUTH_URL}", auth_body, auth_headers)
    body = JSON.parse(response.body)
    body['access_token']
  end
end
