require 'spec_helper'
require_relative '../../../plugins/ib/probability-of-expiring'

# Activate only the plugins under test inside a throw-away module namespace
# to avoid global side effects on IB::Connection.current.
describe 'IB::ProbabilityOfExpiring (unit)' do
  let(:stock) { IB::Stock.new(symbol: 'AAPL', last_trading_day: '2026-06-30') }

  describe '#probability_of_expiring' do
    it 'calculates probability with explicit inputs' do
      result = stock.probability_of_expiring(
        price: 100.0,
        iv: 0.2,
        strike: 110.0,
        expiry: '2026-06-30',
        ref_date: Date.new(2026, 6, 22)
      )
      expect(result).to be_a(Float)
      expect(result).to be_between(0, 1)
    end

    it 'uses last_trading_day if expiry is omitted' do
      result = stock.probability_of_expiring(
        price: 100.0,
        iv: 0.2,
        strike: 110.0,
        ref_date: Date.new(2026, 6, 22)
      )
      expect(result).to be_a(Float)
    end

    it 'raises if iv is missing' do
      expect {
        stock.probability_of_expiring(price: 100, strike: 110)
      }.to raise_error(IB::Error)
    end

    it 'raises if price is missing/zero' do
      expect {
        stock.probability_of_expiring(iv: 0.2, strike: 110, price: 0)
      }.to raise_error(IB::Error)
    end

    it 'raises if strike is missing/zero' do
      expect {
        stock.probability_of_expiring(iv: 0.2, price: 100, strike: 0)
      }.to raise_error(IB::Error)
    end

    it 'raises if expiry cannot be determined' do
      s = IB::Stock.new(symbol: 'X')
      expect {
        s.probability_of_expiring(iv: 0.2, price: 100, strike: 110)
      }.to raise_error(IB::Error)
    end
  end

  describe '#probability_of_assignment' do
    it 'returns the complement of expiring probability' do
      expiring = 0.35
      s = IB::Stock.new(symbol: 'AAPL', last_trading_day: '2026-06-30')
      allow(s).to receive(:probability_of_expiring).and_return(expiring)
      expect(s.probability_of_assignment).to eq((expiring - 1).abs)
    end
  end

  describe 'memoization' do
    it 'memoizes the result when called without args' do
      s = IB::Stock.new(symbol: 'AAPL', last_trading_day: '2026-06-30')
      first = s.probability_of_expiring(price: 100, iv: 0.2, strike: 110)
      allow(s).to receive(:calculate_probability_of_expiring).and_return(0.12345)
      expect(s.probability_of_expiring).to eq(first)
    end
  end
end
