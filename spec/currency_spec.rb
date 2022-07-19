# frozen_string_literal: true

require 'money'
require_relative '../app/currency'

RSpec.describe 'Bitcoin' do
  it 'can be created from an amount' do
    btc = Money.from_amount(100, 'BTC')
    expect(btc.to_f).to eq(100.0)
  end

  it 'can be created from cents' do
    btc = Money.from_cents(100 * 1e+8, 'BTC')
    expect(btc.to_f).to eq(100.0)
  end

  it 'can be converted to satoshis' do
    btc = Money.from_amount(100, 'BTC')
    cents = btc.cents
    expect(cents.to_i).to eq(100 * 1e+8)
  end

  it 'can be compared' do
    from_btc = Money.from_amount(100, 'BTC')
    from_sat = Money.from_cents(100 * 1e+8, 'BTC')
    expect(from_btc).to eq(from_sat)
  end

  it 'can be formatted as a string' do
    btc = Money.from_amount(100, 'BTC')
    str = btc.to_s
    expect(str).to eq('100.00000000')
  end
end
