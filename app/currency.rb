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

Money::Currency.register(bitcoin)
