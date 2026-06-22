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

  describe '#osi=' do
    it 'normalizes to 21 characters' do
      option = IB::Option.new(symbol: 'AAPL')
      option.osi = 'AAPL 241220C00150000'
      expect(option.local_symbol).to eq('AAPL  241220C00150000')
    end
  end

  describe '#next_expiry' do
    before do
      allow(IB::Connection).to receive(:current).and_return(double('connection', plugins: []))
    end

    it 'returns merged option without verify plugin' do
      option = IB::Option.new(symbol: 'AAPL', strike: 150, right: :call)
      result = option.next_expiry('20241201')
      expect(result).to be_a(IB::Option)
      expect(result.expiry).to eq('20241220')
    end

    it 'uses verify plugin when available' do
      allow(IB::Connection).to receive(:current).and_return(double('connection', plugins: ['verify']))
      verified = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150)
      option = IB::Option.new(symbol: 'AAPL', right: :call, strike: 150)
      allow(option).to receive(:merge).and_return(verified)
      allow(verified).to receive(:verify).and_return([verified])

      result = option.next_expiry('20241201')
      expect(result).to eq(verified)
    end

    it 'raises when no expiry can be found' do
      allow(IB::Connection).to receive(:current).and_return(double('connection', plugins: ['verify']))
      option = IB::Option.new(symbol: 'AAPL', right: :call, strike: 150)
      verified = IB::Option.new(symbol: 'AAPL', expiry: '20240101', right: :call, strike: 150)
      allow(option).to receive(:merge).and_return(verified)
      allow(verified).to receive(:verify).and_return([])

      expect { option.next_expiry('20240101') }.to raise_error(IB::LoadError)
    end
  end

  describe 'FutureOption' do
    it 'defaults sec_type to futures_option' do
      fo = IB::FutureOption.new(symbol: 'ES')
      expect(fo.sec_type).to eq(:futures_option)
    end
  end

  describe '#to_human' do
    it 'includes option attributes' do
      option = IB::Option.new(symbol: 'AAPL', expiry: '20241220', right: :call, strike: 150.0)
      expect(option.to_human).to include('AAPL')
      expect(option.to_human).to include('150.0')
      expect(option.to_human).to include('call')
    end
  end

  describe 'validations' do
    it 'rejects non-positive strike' do
      option = IB::Option.new(symbol: 'AAPL', right: :call, strike: 0)
      expect(option).not_to be_valid
    end

    it 'rejects invalid right' do
      option = IB::Option.new(symbol: 'AAPL', right: :none)
      expect(option).not_to be_valid
    end
  end

  describe '.next_expiry edge cases' do
    it 'handles integer day input' do
      result = IB::Option.next_expiry(15)
      expect(result).to match(/\d{8}/)
    end

    it 'handles string month input' do
      result = IB::Option.next_expiry('202412')
      expect(result).to eq('20241220')
    end
  end
end
