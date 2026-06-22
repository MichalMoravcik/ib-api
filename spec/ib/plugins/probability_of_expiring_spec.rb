require 'spec_helper'
require_relative '../../../plugins/ib/probability-of-expiring'

module IB
  class ProbabilityContract < Contract
  end
end

describe IB::ProbabilityOfExpiring do
  let(:contract) { IB::ProbabilityContract.new(symbol: 'AAPL', strike: 150.0) }

  describe '#probability_of_expiring' do
    it 'calculates probability with explicit inputs' do
      p = contract.probability_of_expiring(
        price: 160.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60
      )
      expect(p).to be_a(Float)
      expect(p).to be_between(0.0, 1.0)
    end

    it 'caches the result when called without args' do
      p1 = contract.probability_of_expiring(
        price: 160.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60
      )
      expect(contract.probability_of_expiring).to eq(p1)
    end

    it 'recalculates when new args are provided' do
      p1 = contract.probability_of_expiring(
        price: 160.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60
      )
      p2 = contract.probability_of_expiring(
        price: 140.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60
      )
      expect(p2).not_to eq(p1)
      expect(p2).to be < p1
    end

    it 'uses the contract strike as default' do
      contract_with_strike = IB::ProbabilityContract.new(symbol: 'AAPL', strike: 150.0)
      p = contract_with_strike.probability_of_expiring(
        price: 160.0,
        iv: 0.25,
        expiry: Date.today + 60
      )
      expect(p).to be_between(0.0, 1.0)
    end
  end

  describe '#probability_of_assignment' do
    it 'returns the complement of probability of expiring' do
      p_exp = contract.probability_of_expiring(
        price: 160.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60
      )
      expect(contract.probability_of_assignment(
        price: 160.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60
      )).to eq((p_exp - 1.0).abs)
    end
  end

  describe '#calculate_probability_of_expiring' do
    it 'accepts a custom interest rate' do
      p = contract.probability_of_expiring(
        price: 160.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60,
        interest: 0.05
      )
      expect(p).to be_between(0.0, 1.0)
    end

    it 'uses a reference date' do
      p = contract.probability_of_expiring(
        price: 160.0,
        strike: 150.0,
        iv: 0.25,
        expiry: Date.today + 60,
        ref_date: Date.today - 30
      )
      expect(p).to be_between(0.0, 1.0)
    end
  end
end
