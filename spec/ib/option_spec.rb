require 'spec_helper'

describe IB::Option do
  describe 'basic functionality' do
    it 'creates an option' do
      option = IB::Option.new(
        symbol: 'AAPL',
        expiry: '20241220',
        right: :call,
        strike: 150.0,
        exchange: 'SMART',
        currency: 'USD'
      )
      expect(option).to be_a(IB::Option)
      expect(option.symbol).to eq('AAPL')
      expect(option.sec_type).to eq(:option)
    end

    it 'defaults sec_type to option' do
      option = IB::Option.new(symbol: 'AAPL')
      expect(option.sec_type).to eq(:option)
    end
  end

  describe 'validations' do
    describe 'strike validation' do
      it 'accepts positive strike prices' do
        option = IB::Option.new(symbol: 'AAPL', strike: 150.0)
        expect(option).to be_valid
      end

      it 'rejects zero strike' do
        option = IB::Option.new(symbol: 'AAPL', strike: 0)
        expect(option).not_to be_valid
      end

      it 'rejects negative strike' do
        option = IB::Option.new(symbol: 'AAPL', strike: -150.0)
        expect(option).not_to be_valid
      end
    end

    describe 'sec_type validation' do
      it 'accepts :option' do
        option = IB::Option.new(symbol: 'AAPL', sec_type: :option)
        expect(option).to be_valid
      end

      it 'rejects invalid sec_type' do
        option = IB::Option.new(symbol: 'AAPL', sec_type: :stock)
        expect(option).not_to be_valid
      end
    end

    describe 'right validation' do
      it 'accepts :put' do
        option = IB::Option.new(symbol: 'AAPL', right: :put)
        expect(option).to be_valid
      end

      it 'accepts :call' do
        option = IB::Option.new(symbol: 'AAPL', right: :call)
        expect(option).to be_valid
      end

      it 'accepts "put" string' do
        option = IB::Option.new(symbol: 'AAPL', right: 'put')
        expect(option).to be_valid
      end

      it 'accepts "call" string' do
        option = IB::Option.new(symbol: 'AAPL', right: 'call')
        expect(option).to be_valid
      end
    end

    describe 'local_symbol (OSI code) validation' do
      it 'accepts valid OSI code format' do
        option = IB::Option.new(symbol: 'AAPL', local_symbol: 'AAPL  241220C00150000')
        expect(option).to be_valid
      end

      it 'accepts valid OSI with space' do
        option = IB::Option.new(symbol: 'AAPL', local_symbol: 'AAPL  241220P00150000')
        expect(option).to be_valid
      end

      it 'accepts empty string' do
        option = IB::Option.new(symbol: 'AAPL', local_symbol: '')
        expect(option).to be_valid
      end

      it 'rejects invalid OSI format' do
        option = IB::Option.new(symbol: 'AAPL', local_symbol: 'INVALID')
        expect(option).not_to be_valid
      end
    end
  end

  describe 'OSI code handling' do
    describe '#osi' do
      it 'is alias for local_symbol' do
        option = IB::Option.new(symbol: 'AAPL', local_symbol: 'AAPL  241220C00150000')
        expect(option.osi).to eq(option.local_symbol)
      end
    end

    describe '#osi=' do
      it 'normalizes to 21 characters' do
        option = IB::Option.new(symbol: 'AAPL')
        option.osi = 'AAPL 241220C00150000'
        expect(option.local_symbol.size).to eq(21)
      end

      it 'pads with spaces' do
        option = IB::Option.new(symbol: 'AAPL')
        option.osi = 'AAPL241220C00150000'
        expect(option.local_symbol).to match(/^AAPL /)
      end
    end
  end

  describe '.from_osi' do
    context 'with valid OSI codes' do
      it 'parses AAPL call option' do
        option = IB::Option.from_osi('AAPL  241220C00150000')
        expect(option.symbol).to eq('AAPL')
        expect(option.expiry).to eq('241220')
        expect(option.right).to eq('C')
        expect(option.strike).to eq(150.0)
      end

      it 'parses MSFT put option' do
        option = IB::Option.from_osi('MSFT  241220P00200000')
        expect(option.symbol).to eq('MSFT')
        expect(option.right).to eq('P')
        expect(option.strike).to eq(200.0)
      end

      it 'parses SPY with different strike' do
        option = IB::Option.from_osi('SPY   241220C00400000')
        expect(option.strike).to eq(400.0)
      end

      it 'parses decimal strike' do
        option = IB::Option.from_osi('AAPL  241220C00150500')
        expect(option.strike).to eq(150.5)
      end
    end

    context 'with Saturday expiry' do
      it 'adjusts to Friday' do
        option = IB::Option.from_osi('AAPL  240120C00150000')
        expect(option.expiry).to eq('240119')
      end

      it 'does not adjust non-Saturday dates' do
        option = IB::Option.from_osi('AAPL  241220C00150000')
        expect(option.expiry).to eq('241220')
      end
    end

    context 'with invalid OSI codes' do
      it 'returns nil for invalid format' do
        result = IB::Option.from_osi('INVALID')
        expect(result).to be_nil
      end
    end
  end

  describe '#==' do
    let(:base_option) do
      IB::Option.new(
        symbol: 'AAPL',
        expiry: '20241220',
        right: :call,
        strike: 150.0,
        exchange: 'SMART',
        currency: 'USD'
      )
    end

    it 'returns true for identical options' do
      option2 = base_option.clone
      expect(base_option).to eq(option2)
    end

    it 'returns false for different symbols' do
      option2 = base_option.clone
      option2.symbol = 'MSFT'
      expect(base_option).not_to eq(option2)
    end

    it 'returns false for different expiry' do
      option2 = base_option.clone
      option2.expiry = '20241227'
      expect(base_option).not_to eq(option2)
    end

    it 'returns false for different right' do
      option2 = base_option.clone
      option2.right = :put
      expect(base_option).not_to eq(option2)
    end

    it 'returns false for different strike' do
      option2 = base_option.clone
      option2.strike = 155.0
      expect(base_option).not_to eq(option2)
    end
  end

  describe 'expiry calculations' do
    describe '.next_expiry' do
      it 'returns third Friday of month' do
        result = IB::Option.next_expiry(Date.new(2024, 12, 1))
        expect(result).to match(/\d{8}/)
      end

      it 'calculates correctly for December 2024' do
        result = IB::Option.next_expiry(Date.new(2024, 12, 1))
        expect(result).to eq('20241220')
      end

      it 'calculates correctly for January 2025' do
        result = IB::Option.next_expiry(Date.new(2025, 1, 1))
        expect(result).to eq('20250117')
      end

      it 'moves to next month when past third Friday' do
        result = IB::Option.next_expiry(Date.new(2024, 12, 21))
        expect(result[0..5]).to eq('202501')
      end
    end

    describe '#next_expiry' do
      let(:base_option) do
        IB::Option.new(symbol: 'AAPL', right: :call, strike: 150.0)
      end

      it 'returns option with calculated expiry' do
        result = base_option.next_expiry(Date.today)
        expect(result).to be_a(IB::Option)
        expect(result.expiry).to be_a(String)
      end

      it 'uses block for expiry date' do
        result = base_option.next_expiry { '20241220' }
        expect(result.expiry).to eq('20241220')
      end
    end
  end

  describe '#to_human' do
    it 'returns formatted option description' do
      option = IB::Option.new(
        symbol: 'AAPL',
        expiry: '20241220',
        right: :call,
        strike: 150.0,
        exchange: 'SMART',
        currency: 'USD'
      )
      result = option.to_human
      expect(result).to include('AAPL')
      expect(result).to include('20241220')
      expect(result).to include('call')
      expect(result).to include('150.0')
    end
  end

  describe 'FutureOption subclass' do
    it 'sets sec_type to futures_option' do
      future_option = IB::FutureOption.new(symbol: 'ES')
      expect(future_option.sec_type).to eq(:futures_option)
    end

    it 'inherits Option behavior' do
      future_option = IB::FutureOption.new(symbol: 'ES')
      expect(future_option).to be_a(IB::Option)
    end
  end

  describe 'associations' do
    it 'has_one :greek' do
      option = IB::Option.new(symbol: 'AAPL')
      expect(option).to respond_to(:greek)
    end
  end
end
