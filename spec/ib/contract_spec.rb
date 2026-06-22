require 'spec_helper'

describe IB::Contract do
  let(:contract) do
    IB::Contract.new(
      symbol: 'AAPL',
      sec_type: :stock,
      exchange: 'SMART',
      currency: 'USD',
      con_id: 123
    )
  end

  describe 'type predicates' do
    it 'detects stock' do
      expect(IB::Stock.new.stock?).to be true
      expect(contract.stock?).to be true
    end

    it 'detects option' do
      expect(IB::Option.new(sec_type: :option)).to be_option
    end

    it 'detects bag' do
      expect(IB::Bag.new(sec_type: :bag)).to be_bag
    end

    it 'detects bond' do
      expect(IB::Contract.new(sec_type: :bond).bond?).to be true
    end
  end

  describe '#serialize' do
    it 'serializes a stock contract' do
      result = contract.serialize_short
      expect(result).to include('AAPL')
      expect(result).to include('STK')
      expect(result).to include('SMART')
    end

    it 'serializes an option contract' do
      option = IB::Option.new(
        symbol: 'AAPL',
        sec_type: :option,
        expiry: '20251220',
        strike: 150.0,
        right: :call,
        exchange: 'SMART',
        currency: 'USD'
      )
      result = option.serialize_short
      expect(result).to include('AAPL')
      expect(result).to include('OPT')
      expect(result).to include(150.0)
      expect(result).to include('C')
    end

    it 'includes primary exchange when requested' do
      c = IB::Contract.new(symbol: 'AAPL', sec_type: :stock, exchange: 'SMART', primary_exchange: 'NASDAQ')
      result = c.serialize(:primary_exchange)
      expect(result).to include('NASDAQ')
    end

    it 'includes trading class when requested' do
      c = IB::Contract.new(symbol: 'AAPL', sec_type: :stock, trading_class: 'AAPL')
      result = c.serialize(:trading_class)
      expect(result).to include('AAPL')
    end
  end

  describe '#serialize_long and #serialize_ib_ruby' do
    it 'produces colon-separated string' do
      str = contract.serialize_ib_ruby
      expect(str).to include('AAPL')
      expect(str).to include(':')
    end
  end

  describe '#serialize_legs' do
    it 'returns empty for non-bag' do
      expect(contract.serialize_legs).to eq([])
    end

    it 'returns leg count and serialized legs for bag' do
      bag = IB::Bag.new(sec_type: :bag)
      leg1 = IB::ComboLeg.new(con_id: 1, ratio: 1, side: :buy, exchange: 'SMART')
      leg2 = IB::ComboLeg.new(con_id: 2, ratio: 1, side: :sell, exchange: 'SMART')
      bag.combo_legs = [leg1, leg2]
      result = bag.serialize_legs
      expect(result.first).to eq(2)
    end
  end

  describe '#serialize_under_comp' do
    it 'returns false array when no under comp' do
      expect(contract.serialize_under_comp).to eq([false])
    end

    it 'serializes under comp when present' do
      contract.underlying = IB::Underlying.new(con_id: 999, delta: 0.5, price: 100.0)
      result = contract.serialize_under_comp
      expect(result.first).to be true
      expect(result).to include(999)
    end
  end

  describe '#==' do
    it 'matches by con_id' do
      other = IB::Contract.new(con_id: 123)
      expect(contract).to eq(other)
    end

    it 'matches by attributes' do
      other = IB::Contract.new(symbol: 'AAPL', sec_type: :stock, exchange: 'SMART')
      expect(contract).to eq(other)
    end
  end

  describe '#essential' do
    it 'returns a new contract with essential attributes' do
      essential = contract.essential
      expect(essential.symbol).to eq('AAPL')
      expect(essential.sec_type).to eq(:stock)
    end
  end

  describe '#merge' do
    it 'creates new contract with reset con_id and local_symbol' do
      merged = contract.merge(symbol: 'MSFT')
      expect(merged.symbol).to eq('MSFT')
      expect(merged.con_id).to be_zero
      expect(merged.local_symbol).to eq('')
    end
  end

  describe '#expiry' do
    it 'returns last_trading_day if present' do
      c = IB::Contract.new(expiry: '20251220', last_trading_day: '20251219-16:00')
      expect(c.expiry).to eq('2025121916:00')
    end
  end

  describe '#time_zone' do
    it 'returns currency-based timezone' do
      expect(IB::Contract.new(currency: 'EUR').time_zone).to eq('MET')
      expect(IB::Contract.new(currency: 'USD').time_zone).to eq('US/Eastern')
    end
  end

  describe 'validations' do
    it 'rejects SMART primary exchange' do
      c = IB::Contract.new(primary_exchange: 'SMART')
      expect(c).not_to be_valid
    end

    it 'rejects invalid sec_type' do
      c = IB::Contract.new(sec_type: :invalid)
      expect(c).not_to be_valid
    end
  end
end
