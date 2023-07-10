# frozen_string_literal: true

module Config
  BANK_GUID = ENV['BANK_GUID']
  BASE_URL = ENV['BASE_URL']
  URL_SCHEME = ENV.fetch('URL_SCHEME', 'https')
  CLIENT_ID = ENV['APPLICATION_CLIENT_ID']
  CLIENT_SECRET = ENV['APPLICATION_CLIENT_SECRET']
  TIMEOUT = ENV.fetch('TIMEOUT', 30).to_i
  CRYPTO_ASSETS = ENV.fetch('CRYPTO_ASSETS', 'BTC').split(',')
end
