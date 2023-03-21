#!/usr/bin/env ruby
# frozen_string_literal: true

# 1. Create a customer
# 2. Create an attested identity verification for the customer
# 3. Create a USD fiat account for the customer
# 4. Create a BTC-USD trading account for the customer
# 5. Generate a book transfer quote in USD
# 6. Execute the book transfer quote using a transfer
# 7. Get the balance of the customer's USD fiat account
# 8. Generate a buy quote in BTC-USD
# 9. Execute the buy quote using a trade
# 10. Get the balance of the customer's BTC-USD trading account

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
STATE_UNVERIFIED = 'unverified'

class BadResultError < StandardError; end
class TimeoutError < StandardError; end

def configure
  CybridApiBank.configure do |config|
    config.access_token = Auth.token
    config.scheme = Config::URL_SCHEME
    config.host = "bank.#{Config::BASE_URL}"
    config.server_index = nil
  end
end

def create_person
  {
    name: {
      first: 'Jane',
      middle: nil,
      last: 'Doe',
    },
    address: {
      street: '15310 Taylor Walk Suite 995',
      street2: nil,
      city: 'New York',
      subdivision: 'NY',
      postal_code: '12099',
      country_code: 'US',
    },
    date_of_birth: '2001-01-01',
    email_address: 'jane.doe@example.org',
    phone_number: '+12406525665',
    identification_numbers: [
      {
        type: 'social_security_number',
        issuing_country_code: 'US',
        identification_number: '669-55-0349',
      },
      {
        type: 'drivers_license',
        issuing_country_code: 'US',
        identification_number: 'D152096714850065',
      }
    ]
  }
end

def create_customer(person)
  LOGGER.info('Creating customer...')

  api_customers = CybridApiBank::CustomersBankApi.new
  customer_params = { 
    type: 'individual',
    name: CybridApiBank::PostCustomerNameBankModel.new(person[:name]),
    address: CybridApiBank::PostCustomerAddressBankModel.new(person[:address]),
    date_of_birth: Date.parse(person[:date_of_birth]),
    email_address: person[:email_address],
    phone_number: person[:phone_number],
    identification_numbers: person[:identification_numbers].map do |x| 
      CybridApiBank::PostIdentificationNumberBankModel.new(x)
    end
  }
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

def get_customer(guid)
  LOGGER.info('Getting customer...')

  api_customers = CybridApiBank::CustomersBankApi.new
  customer = api_customers.get_customer(guid)

  LOGGER.info('Got customer.')

  customer
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when getting customer: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when getting customer: #{e}")
  raise e
end

def wait_for_customer_unverified(customer)
  timeout = Config::TIMEOUT
  customer_state = customer.state

  timeout_message = LazyStr.new { "Customer creation was not completed in time. State: #{customer_state}" }
  Timeout.timeout(timeout, TimeoutError, timeout_message) do
    final_states = [STATE_UNVERIFIED]
    until final_states.include?(customer_state)
      sleep(1)
      customer = get_customer(customer.guid)
      customer_state = customer.state
    end
  end
  raise BadResultError, "Customer has invalid state: #{customer_state}" unless customer_state == STATE_UNVERIFIED

  LOGGER.info("Customer successfully created with state: #{customer_state}")
end

def create_account(customer, type, asset)
  LOGGER.info("Creating #{type} account for asset #{asset}...")

  api_accounts = CybridApiBank::AccountsBankApi.new
  account_params = {
    type: type,
    customer_guid: customer.guid,
    asset: asset,
    name: "#{asset} account for #{customer.guid}"
  }
  post_account_bank_model = CybridApiBank::PostAccountBankModel.new(account_params)
  account = api_accounts.create_account(post_account_bank_model)

  LOGGER.info("Created #{type} account.")

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

def wait_for_account_created(account)
  timeout = Config::TIMEOUT
  account_state = account.state

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
end

def create_identity_verification(customer, person)
  LOGGER.info('Creating identity verification...')

  api_identity = CybridApiBank::IdentityVerificationsBankApi.new
  identity_verification_params = {
    type: 'kyc',
    method: 'attested',
    customer_guid: customer.guid,
    name: CybridApiBank::PostIdentityVerificationNameBankModel.new(person[:name]),
    address: CybridApiBank::PostIdentityVerificationAddressBankModel.new(person[:address]),
    date_of_birth: Date.parse(person[:date_of_birth]),
    identification_numbers: person[:identification_numbers].map do |x| 
      CybridApiBank::PostIdentificationNumberBankModel.new(x)
    end
  }
  post_identity_verification_model = CybridApiBank::PostIdentityVerificationBankModel.new(identity_verification_params)
  identity_verification = api_identity.create_identity_verification(post_identity_verification_model)

  LOGGER.info('Created identity verification.')

  identity_verification
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating identity: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating identity: #{e}")
  raise e
end

def get_identity_verification(guid)
  LOGGER.info('Getting identity verification...')

  api_identity = CybridApiBank::IdentityVerificationsBankApi.new
  identity_verification = api_identity.get_identity_verification(guid)

  LOGGER.info('Got identity verification.')

  identity_verification
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when getting identity: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when getting identity: #{e}")
  raise e
end

def wait_for_identity_verification_completed(identity_verification)
  timeout = Config::TIMEOUT
  identity_verification_state = identity_verification.state

  timeout_message = LazyStr.new { "Identity verification was not completed in time. State: #{identity_verification_state}" }
  Timeout.timeout(timeout, TimeoutError, timeout_message) do
    final_states = [STATE_COMPLETED]
    until final_states.include?(identity_verification_state)
      sleep(1)
      identity_verification = get_identity_verification(identity_verification.guid)
      identity_verification_state = identity_verification.state
    end
  end
  raise BadResultError, "Identity verification has invalid state: #{identity_verification_state}" unless identity_verification_state == STATE_COMPLETED

  LOGGER.info("Identity verification successfully created with state: #{identity_verification_state}")
end

# rubocop:disable Metrics/AbcSize, Metrics/ParameterLists
def create_quote(customer, product_type, side, receive_amount, symbol: nil, asset: nil)
  LOGGER.info("Creating #{side} #{product_type} quote for #{symbol}#{asset} of #{receive_amount}...")

  buy_quote_params = {
    product_type: product_type,
    customer_guid: customer.guid,
    side: side,
    receive_amount: receive_amount.to_i
  }
  buy_quote_params[:symbol] = symbol unless symbol.nil?
  buy_quote_params[:asset] = asset unless asset.nil?

  api_quotes = CybridApiBank::QuotesBankApi.new
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
# rubocop:enable Metrics/AbcSize, Metrics/ParameterLists

def create_transfer(quote, transfer_type, one_time_address = nil)
  LOGGER.info("Creating #{transfer_type} transfer...")

  api_transfers = CybridApiBank::TransfersBankApi.new
  transfer_params = {
    quote_guid: quote.guid,
    transfer_type: transfer_type
  }
  transfer_params[:one_time_address] = one_time_address unless one_time_address.nil?
  post_transfer_model = CybridApiBank::PostTransferBankModel.new(transfer_params)
  transfer = api_transfers.create_transfer(post_transfer_model)

  LOGGER.info('Created transfer.')

  transfer
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when creating transfer: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when creating transfer: #{e}")
  raise e
end

def get_transfer(guid)
  LOGGER.info('Getting transfer...')

  api_transfers = CybridApiBank::TransfersBankApi.new
  trade = api_transfers.get_transfer(guid)

  LOGGER.info('Got transfer.')

  trade
rescue CybridApiBank::ApiError => e
  LOGGER.error("An API error occurred when getting transfer: #{e}")
  raise e
rescue StandardError => e
  LOGGER.error("An unknown error occurred when getting transfer: #{e}")
  raise e
end

def wait_for_transfer_created(transfer)
  timeout = Config::TIMEOUT
  transfer_state = transfer.state

  timeout_message = LazyStr.new { "Transfer was not executed in time. State: #{transfer_state}." }
  Timeout.timeout(timeout, TimeoutError, timeout_message) do
    final_states = [STATE_COMPLETED]
    until final_states.include?(transfer_state)
      sleep(1)
      transfer = get_transfer(transfer.guid)
      transfer_state = transfer.state
    end
  end
  raise BadResultError, "Trade has invalid state: #{transfer_state}" unless transfer_state == STATE_COMPLETED

  LOGGER.info("Trade successfully created with state: #{transfer_state}")
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

def wait_for_trade_created(trade)
  timeout = Config::TIMEOUT
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
end

begin
  configure
  timeout = Config::TIMEOUT
  person = create_person

  #
  # Create customer
  #

  customer = create_customer(person)
  wait_for_customer_unverified(customer)

  #
  # Create identity verifications
  #

  identity_verification = create_identity_verification(customer, person)
  wait_for_identity_verification_completed(identity_verification)

  #
  # Create accounts
  #

  # Fiat USD account

  fiat_usd_account = create_account(customer, 'fiat', 'USD')
  wait_for_account_created(fiat_usd_account)

  # Crypto BTC account

  crypto_btc_account = create_account(customer, 'trading', 'BTC')
  wait_for_account_created(crypto_btc_account)

  #
  # Add fiat funds to account
  #

  usd_quantity = Money.from_amount(1_000, 'USD')
  fiat_book_transfer_quote = create_quote(customer, 'book_transfer', 'deposit', usd_quantity.cents, asset: 'USD')
  transfer = create_transfer(fiat_book_transfer_quote, 'book')

  wait_for_transfer_created(transfer)

  #
  # Check USD balance
  #

  fiat_usd_account = get_account(fiat_usd_account.guid)
  fiat_balance = Money.from_cents(fiat_usd_account.platform_balance, 'USD')
  unless fiat_balance == usd_quantity
    raise BadResultError,
          "Fiat USD account has an unexpected balance: #{fiat_balance}"
  end

  LOGGER.info("Fiat USD account has the expected balance: #{fiat_balance}")

  #
  # Purchase BTC
  #

  btc_quantity = Money.from_amount(0.001, 'BTC')
  crypto_trading_btc_quote = create_quote(customer, 'trading', 'buy', btc_quantity.cents, symbol: 'BTC-USD')
  trade = create_trade(crypto_trading_btc_quote)

  wait_for_trade_created(trade)

  #
  # Check BTC balance
  #

  crypto_btc_account = get_account(crypto_btc_account.guid)
  crypto_balance = Money.from_cents(crypto_btc_account.platform_balance, 'BTC')
  unless crypto_balance == btc_quantity
    raise BadResultError,
          "Crypto BTC account has an unexpected balance: #{crypto_balance}"
  end

  #
  # Transfer BTC
  #

  btc_withdrawal_quantity = Money.from_amount(0.0005, 'BTC')
  crypto_withdrawal_btc_quote = create_quote(customer, 'crypto_transfer', 'withdrawal', btc_withdrawal_quantity.cents,
                                             asset: 'BTC')
  crypto_transfer = create_transfer(
    crypto_withdrawal_btc_quote,
    'crypto',
    CybridApiBank::PostOneTimeAddressBankModel.new(
      address: SecureRandom.base64(16),
      tag: nil
    )
  )

  wait_for_transfer_created(crypto_transfer)

  #
  # Check BTC balance
  #

  crypto_btc_account = get_account(crypto_btc_account.guid)
  crypto_balance = Money.from_cents(crypto_btc_account.platform_balance, 'BTC')

  unless crypto_balance == (btc_quantity - btc_withdrawal_quantity)
    raise BadResultError, "Crypto BTC account has an unexpected balance: #{crypto_balance}"
  end

  LOGGER.info("Crypto BTC account has the expected balance: #{crypto_balance}")

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
