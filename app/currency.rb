# frozen_string_literal: true

require 'i18n'
require 'money'

I18n.enforce_available_locales = false
Money.rounding_mode = BigDecimal::ROUND_HALF_UP

bitcoin = {
  iso_code: 'BTC',
  name: 'Bitcoin',
  symbol: '₿',
  subunit: 'satoshi',
  subunit_to_unit: 100_000_000,
  separator: '.',
  delimiter: ','
}

ethereum = {
  iso_code: 'ETH',
  name: 'Ethereum',
  symbol: 'Ξ',
  subunit: 'wei',
  subunit_to_unit: 1_000_000_000_000_000_000,
  separator: '.',
  delimiter: ','
}

solana = {
  iso_code: 'SOL',
  name: 'Solana',
  symbol: '◎',
  subunit: 'lamport',
  subunit_to_unit: 1_000_000_000,
  separator: '.',
  delimiter: ','
}

usdc = {
  iso_code: 'USDC',
  name: 'USDC',
  symbol: '$',
  subunit: 'cents',
  subunit_to_unit: 1_000_000,
  separator: '.',
  delimiter: ','
}

usdc_sol = {
  iso_code: 'USDC_SOL',
  name: 'USDC (SOL)',
  symbol: '$',
  subunit: 'cents',
  subunit_to_unit: 1_000_000,
  separator: '.',
  delimiter: ','
}

usdc_pol = {
  iso_code: 'USDC_POL',
  name: 'USDC (POL)',
  symbol: '$',
  subunit: 'cents',
  subunit_to_unit: 1_000_000,
  separator: '.',
  delimiter: ','
}

usdc_ste = {
  iso_code: 'USDC_STE',
  name: 'USDC (STE)',
  symbol: '$',
  subunit: 'cents',
  subunit_to_unit: 10_000_000,
  separator: '.',
  delimiter: ','
}

bitcoin_cash = {
  iso_code: 'BCH',
  name: 'Bitcoin Cash',
  symbol: 'Ƀ',
  subunit: 'satoshi',
  subunit_to_unit: 100_000_000,
  separator: '.',
  delimiter: ','
}

litecoin = {
  iso_code: 'LTC',
  name: 'Litecoin',
  symbol: 'Ł',
  subunit: 'litoshi',
  subunit_to_unit: 100_000_000,
  separator: '.',
  delimiter: ','
}


Money::Currency.register(bitcoin)
Money::Currency.register(ethereum)
Money::Currency.register(solana)
Money::Currency.register(usdc)
Money::Currency.register(usdc_sol)
Money::Currency.register(usdc_pol)
Money::Currency.register(usdc_ste)
Money::Currency.register(bitcoin_cash)
Money::Currency.register(litecoin)
