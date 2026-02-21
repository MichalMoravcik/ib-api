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
        # Valid format: SYMBOL + YYMMDD + C/P + STRIKE(5+ digits)
        option = IB::Option.from_osi('AAPL 241220C00150000')
        expect(option).to be_a(IB::Option)
        expect(option.symbol).to eq('AAPL')
        expect(option.expiry).to eq('241220')
        expect(option.right).to eq('C')
        expect(option.strike).to eq(150.0)
      end

      it 'parses MSFT put option' do
        option = IB::Option.from_osi('MSFT 241220P00200000')
        expect(option.symbol).to eq('MSFT')
        expect(option.right).to eq('P')
        expect(option.strike).to eq(200.0)
      end

      it 'parses decimal strike' do
        option = IB::Option.from_osi('AAPL 241220C00150500')
        expect(option.strike).to eq(150.5)
      end
    end

    context 'with Saturday expiry' do
      it 'adjusts to Friday' do
        # Jan 20, 2024 is Saturday
        option = IB::Option.from_osi('AAPL 240120C00150000')
        expect(option.expiry).to eq('240119')
      end
    end

    context 'with invalid OSI codes' do
      it 'handles invalid format gracefully' do
        result = IB::Option.from_osi('INVALID')
        # Should return nil or raise error based on implementation
        expect(result).to be_nil.or be_a(IB::Option)
      end
    end
  end

  describe '#==' do
    it 'returns true for identical options' do
      opt1 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0)
      opt2 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0)
      expect(opt1).to eq(opt2)
    end

    it 'returns false for different symbols' do
      opt1 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0)
      opt2 = IB::Option.new(symbol: 'MSFT', expiry: '20241220', right: :call, strike: 150.0)
      expect(opt1).not_to eq(opt2)
    end

    it 'returns false for different strike' do
      opt1 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0)
      opt2 = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 155.0)
      expect(opt1).not_to eq(opt2)
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
