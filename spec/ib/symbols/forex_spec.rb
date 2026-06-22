require 'spec_helper'
require_relative '../../../plugins/ib/symbols/forex'

describe IB::Symbols::Forex do
  describe '.contracts' do
    it 'returns a hash of pre-defined forex contracts' do
      contracts = IB::Symbols::Forex.contracts
      expect(contracts).to be_a(Hash)
      expect(contracts).not_to be_empty
    end

    it 'caches the contracts hash' do
      first = IB::Symbols::Forex.contracts
      second = IB::Symbols::Forex.contracts
      expect(first.object_id).to eq(second.object_id)
    end

    it 'includes a EURUSD contract' do
      expect(IB::Symbols::Forex.contracts).to have_key(:eurusd)
    end

    it 'does not include same-currency pairs' do
      expect(IB::Symbols::Forex.contracts).not_to have_key(:usdusd)
      expect(IB::Symbols::Forex.contracts).not_to have_key(:eureur)
    end

    it 'defines contracts on IDEALPRO' do
      eurusd = IB::Symbols::Forex.contracts[:eurusd]
      expect(eurusd).to be_an(IB::Forex)
      expect(eurusd.exchange).to eq('IDEALPRO')
    end

    it 'sets symbol to the base currency' do
      gbpusd = IB::Symbols::Forex.contracts[:gbpusd]
      expect(gbpusd.symbol).to eq('GBP')
    end

    it 'sets currency to the quote currency' do
      gbpusd = IB::Symbols::Forex.contracts[:gbpusd]
      expect(gbpusd.currency).to eq('USD')
    end

    it 'sets local_symbol to BASE.QUOTE format' do
      gbpusd = IB::Symbols::Forex.contracts[:gbpusd]
      expect(gbpusd.local_symbol).to eq('GBP.USD')
    end

    it 'covers all combinations of supported currencies' do
      currencies = %w[aud cad chf eur gbp hkd jpy nzd usd]
      expected_pairs = currencies.permutation(2).map { |a, b| "#{a}#{b}".downcase.to_sym }
      contracts = IB::Symbols::Forex.contracts
      expected_pairs.each do |pair|
        expect(contracts).to have_key(pair)
      end
    end
  end
end
