#!/usr/bin/env ruby
# frozen_string_literal: true

# 1. Create a customer
# 2. Create a BTC-USD trading account
# 3. Create an identity record
# 4. Generate a buy quote for BTC-USD
# 5. Execute the buy quote
# 6. Get a balance of the customer's BTC-USD trading account

require 'base64'
require 'dotenv/load'
require 'faraday'
require 'timeout'

require 'cybrid_api_bank_ruby'

require_relative 'auth'
require_relative 'config'
require_relative 'currency'
require_relative 'util'

LOGGER = Logger.new($stdout)

STATE_CREATED = 'created'
STATE_COMPLETED = 'completed'
STATE_FAILED = 'failed'
STATE_SETTLING = 'settling'
STATE_VERIFIED = 'verified'

class BadResultError < StandardError; end
class TimeoutError < StandardError; end

def configure
  CybridApiBank.configure do |config|
    config.access_token = Auth.token
  end
end

def create_trade_configuration
  LOGGER.info('Creating trade configuration...')

  api_trade_configurations = CybridApiBank::TradingConfigurationsBankApi.new
  trade_configuration_params = {
    asset: 'USD',
    fees: [
      {
        type: 'spread',
        spread_fee: 50
      }
    ]
  }
  post_trade_configuration_model = CybridApiBank::PostTradingConfigurationBankModel.new(trade_configuration_params)
  trade_configuration = api_trade_configurations.create_trading_configuration(post_trade_configuration_model)

  LOGGER.info('Created trade configuration.')

  trade_configuration
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating trade configuration: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating trade configuration: #{e}")
  raise e
end

def create_customer
  LOGGER.info('Creating customer...')

  api_customers = CybridApiBank::CustomersBankApi.new
  customer_params = { type: 'individual' }
  post_customer_bank_model = CybridApiBank::PostCustomerBankModel.new(customer_params)
  customer = api_customers.create_customer(post_customer_bank_model)

  LOGGER.info('Created customer.')

  customer
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating customer: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating customer: #{e}")
  raise e
end

def create_account(customer)
  LOGGER.info('Creating account...')

  api_accounts = CybridApiBank::AccountsBankApi.new
  account_params = {
    type: 'trading',
    customer_guid: customer.guid,
    asset: 'BTC',
    name: 'Account'
  }
  post_account_bank_model = CybridApiBank::PostAccountBankModel.new(account_params)
  account = api_accounts.create_account(post_account_bank_model)

  LOGGER.info('Created account.')

  account
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating account: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating account: #{e}")
  raise e
end

def get_account(guid)
  LOGGER.info('Getting account...')

  api_accounts = CybridApiBank::AccountsBankApi.new
  account = api_accounts.get_account(guid)

  LOGGER.info('Got account.')

  account
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when getting account: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when getting account: #{e}")
  raise e
end

def list_verification_keys
  LOGGER.info('Getting verification keys...')

  api_verification = CybridApiBank::VerificationKeysBankApi.new
  verification_keys = api_verification.list_verification_keys

  LOGGER.info('Got verification keys.')

  verification_keys
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when getting verification key: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when getting verification key: #{e}")
  raise e
end

def create_identity(rsa_signing_key, verification_key, customer)
  LOGGER.info('Creating identity record...')

  bank_guid = Config::BANK_GUID
  token = create_jwt(rsa_signing_key, verification_key, customer, bank_guid)
  api_identity = CybridApiBank::IdentityRecordsBankApi.new
  identity_record_params = {
    customer_guid: customer.guid,
    type: 'attestation',
    attestation_details: {
      token: token
    }
  }
  post_identity_record_model = CybridApiBank::IdentityRecordBankModel.new(identity_record_params)
  identity_record = api_identity.create_identity_record(post_identity_record_model)

  LOGGER.info('Created identity record.')

  identity_record
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating identity: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating identity: #{e}")
  raise e
end

def get_identity(guid)
  LOGGER.info('Getting identity record...')

  api_identity = CybridApiBank::IdentityRecordsBankApi.new
  identity_record = api_identity.get_identity_record(guid)

  LOGGER.info('Got identity record.')

  identity_record
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when getting identity: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when getting identity: #{e}")
  raise e
end

def create_quote(customer, side, symbol, receive_amount)
  LOGGER.info("Creating #{side} #{symbol} quote of #{receive_amount}...")

  api_quotes = CybridApiBank::QuotesBankApi.new
  buy_quote_params = {
    customer_guid: customer.guid,
    side: side,
    symbol: symbol,
    receive_amount: receive_amount.to_i
  }
  post_quote_model = CybridApiBank::QuoteBankModel.new(buy_quote_params)
  quote = api_quotes.create_quote(post_quote_model)

  LOGGER.info('Created quote.')

  quote
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating quote: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating quote: #{e}")
  raise e
end

def create_trade(quote)
  LOGGER.info('Creating trade...')

  api_trades = CybridApiBank::TradesBankApi.new
  trade_params = {
    quote_guid: quote.guid
  }
  post_trade_model = CybridApiBank::PostTradeBankModel.new(trade_params)
  trade = api_trades.create_trade(post_trade_model)

  LOGGER.info('Created trade.')

  trade
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating trade: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating trade: #{e}")
  raise e
end

def get_trade(guid)
  LOGGER.info('Getting trade...')

  api_trades = CybridApiBank::TradesBankApi.new
  trade = api_trades.get_trade(guid)

  LOGGER.info('Got trade.')

  trade
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when getting trade: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when getting trade: #{e}")
  raise e
end

begin
  configure

  timeout = Config::TIMEOUT

  verification_key = list_verification_keys.objects.first
  verification_key_state = verification_key.state
  raise BadResultError, "Verification key has invalid state: #{verification_key_state}" unless verification_key_state == STATE_VERIFIED

  create_trade_configuration
  customer = create_customer
  account = create_account(customer)
  account_state = account.state

  attestation_signing_key = OpenSSL::PKey.read(Config::ATTESTATION_SIGNING_KEY)
  identity_record = create_identity(attestation_signing_key, verification_key, customer)
  identity_record_state = identity_record.attestation_details.state

  timeout_message = LazyStr.new { "Account creation was not completed in time. State: #{account_state}" }
  Timeout.timeout(timeout, TimeoutError, timeout_message) do
    final_states = [STATE_CREATED]
    until final_states.include?(account_state)
      sleep(1)
      account = get_account(account.guid)
      account_state = account.state
    end
  end
  raise BadResultError, "Account has invalid state: #{account_state}" unless account_state == STATE_CREATED

  LOGGER.info("Account successfully created with state: #{account_state}")

  timeout_message = LazyStr.new { "Identity record verification was not completed in time. State: #{identity_record_state}" }
  Timeout.timeout(timeout, TimeoutError, timeout_message) do
    final_states = [STATE_VERIFIED, STATE_FAILED]
    until final_states.include?(identity_record_state)
      sleep(1)
      identity_record = get_identity(identity_record.guid)
      identity_record_state = identity_record.attestation_details.state
    end
  end
  raise BadResultError, "Identity record has invalid state: #{identity_record_state}" unless identity_record_state == STATE_VERIFIED

  LOGGER.info("Identity record successfully created with state: #{identity_record_state}")

  quantity = Money.from_amount(5, 'BTC')
  quote = create_quote(customer, 'buy', 'BTC-USD', quantity.cents)
  trade = create_trade(quote)
  trade_state = trade.state

  timeout_message = LazyStr.new { "Trade was not executed in time. State: #{trade_state}." }
  Timeout.timeout(timeout, TimeoutError, timeout_message) do
    final_states = [STATE_SETTLING, STATE_COMPLETED, STATE_FAILED]
    until final_states.include?(trade_state)
      sleep(1)
      trade = get_trade(trade.guid)
      trade_state = trade.state
    end
  end
  raise BadResultError, "Trade has invalid state: #{trade_state}" unless trade_state == STATE_SETTLING

  LOGGER.info("Trade successfully created with state: #{trade_state}")

  account = get_account(account.guid)
  balance = Money.from_cents(account.platform_balance, 'BTC')
  raise BadResultError, "Account has an unexpected balance: #{balance}" unless balance == quantity

  LOGGER.info("Account has the expected balance: #{balance}")
  LOGGER.info('Test has completed successfully!')
rescue CybridApiBank::ApiError => e
  LOGGER.error("Test failed due to an API error: #{e}")
  raise e
rescue TimeoutError => e
  LOGGER.error("Test failed due to a timeout: #{e}")
rescue StandardError => e
  LOGGER.error("Test failed due to an unexpected error: #{e}")
  raise e
end
