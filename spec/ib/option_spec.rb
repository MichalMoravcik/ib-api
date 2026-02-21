require 'spec_helper'

describe IB::Option do
  describe 'basic functionality' do
    it 'creates an option' do
      option = IB::Option.new(
        symbol: 'AAPL',
        expiry: '20241220',
        right: :call,
        strike: 150.0
      )
      expect(option).to be_a(IB::Option)
      expect(option.symbol).to eq('AAPL')
      expect(option.sec_type).to eq(:option)
    end

    it 'defaults sec_type to option' do
      option = IB::Option.new(symbol: 'AAPL', right: :call)
      expect(option.sec_type).to eq(:option)
    end
  end

  describe '.from_osi' do
    context 'with valid OSI codes' do
      it 'parses AAPL call option' do
        option = IB::Option.from_osi('AAPL 241220C00150000')
        expect(option).to be_a(IB::Option)
        expect(option.symbol).to eq('AAPL')
        expect(option.expiry).to eq('241220')
        expect(option.right).to eq(:call)
        expect(option.strike).to eq(150.0)
      end

      it 'parses MSFT put option' do
        option = IB::Option.from_osi('MSFT 241220P00200000')
        expect(option.symbol).to eq('MSFT')
        expect(option.right).to eq(:put)
        expect(option.strike).to eq(200.0)
      end

      it 'parses decimal strike' do
        option = IB::Option.from_osi('AAPL 241220C00150500')
        expect(option.strike).to eq(150.5)
      end
    end

    context 'with Saturday expiry' do
      it 'adjusts to Friday' do
        option = IB::Option.from_osi('AAPL 240120C00150000')
        expect(option.expiry).to eq('240119')
      end
    end

    context 'with invalid OSI codes' do
      it 'raises error for invalid format' do
        expect do
          IB::Option.from_osi('INVALID')
        end.to raise_error(NoMethodError)
      end
    end
  end

  describe '#==' do
    it 'compares options by attributes' do
      opt1 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0, con_id: 12345)
      opt2 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0, con_id: 12345)
      expect(opt1).to eq(opt2)
    end

    it 'differentiates options with different symbols' do
      opt1 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0, con_id: 12345)
      opt2 = IB::Option.new(symbol: 'MSFT', expiry: '20241220', right: :call, strike: 150.0, con_id: 67890)
      expect(opt1.symbol).not_to eq(opt2.symbol)
    end

    it 'differentiates options with different strikes' do
      opt1 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0, con_id: 12345)
      opt2 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 155.0, con_id: 67890)
      expect(opt1.strike).not_to eq(opt2.strike)
    end
  end

  describe '.next_expiry' do
    it 'returns third Friday of month' do
      result = IB::Option.next_expiry(Date.new(2024, 12, 1))
      expect(result).to match(/\d{8}/)
      expect(result).to eq('20241220')
    end

    it 'moves to next month when past third Friday' do
      result = IB::Option.next_expiry(Date.new(2024, 12, 21))
      expect(result[0..5]).to eq('202501')
    end
  end

  describe '#to_human' do
    it 'returns formatted option description' do
      option = IB::Option.new(
        symbol: 'AAPL',
        expiry: '20241220',
        right: :call,
        strike: 150.0
      )
      result = option.to_human
      expect(result).to be_a(String)
      expect(result).to include('AAPL')
    end
  end
end
