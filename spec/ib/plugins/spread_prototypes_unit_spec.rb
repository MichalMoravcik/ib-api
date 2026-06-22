require 'spec_helper'

# Save/restore Connection.current because spread-prototypes activates
# sub-plugins via IB::Connection.current during file load.
_original_connection = IB::Connection.current
IB::Connection.current = IB::Connection.new.tap { |c| c.instance_variable_set(:@socket, IB::SocketStub.new) }
require_relative '../../../plugins/ib/spread-prototypes'
IB::Connection.current = _original_connection

# Unit tests for spread prototype plugins using stubbed verify.
describe 'IB::Spread prototypes (unit)' do
  let(:call_option) do
    IB::Option.new(
      symbol: 'AAPL',
      expiry: '20241220',
      right: :call,
      strike: 150.0,
      exchange: 'SMART',
      currency: 'USD',
      con_id: 1001,
      last_trading_day: '2024-12-20'
    )
  end

  let(:put_option) do
    IB::Option.new(
      symbol: 'AAPL',
      expiry: '20241220',
      right: :put,
      strike: 150.0,
      exchange: 'SMART',
      currency: 'USD',
      con_id: 1002,
      last_trading_day: '2024-12-20'
    )
  end

  let(:stock) { IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD', con_id: 2001) }

  after do
    IB::Connection.current = nil
  end

  describe IB::Calendar do
    it 'returns parameters' do
      expect(IB::Calendar.parameters).to include('Required')
    end

    it 'returns defaults' do
      expect(IB::Calendar.defaults).to include(right: :put)
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg call_option, action: :buy
      spread.add_leg put_option, action: :sell
      expect(IB::Calendar.the_description(spread)).to include('Calendar')
    end
  end

  describe IB::Vertical do
    it 'returns parameters' do
      expect(IB::Vertical.parameters).to include('Required')
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg call_option, action: :buy
      spread.add_leg put_option.merge(strike: 155), action: :sell
      expect(IB::Vertical.the_description(spread)).to include('Vertical')
    end
  end

  describe IB::Butterfly do
    it 'returns parameters' do
      expect(IB::Butterfly.parameters).to include('Required')
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      [140, 150, 160].each { |strike| spread.add_leg call_option.merge(strike: strike) }
      expect(IB::Butterfly.the_description(spread)).to include('Butterfly')
    end
  end

  describe IB::Strangle do
    it 'returns parameters' do
      expect(IB::Strangle.parameters).to include('Required')
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg put_option.merge(strike: 145)
      spread.add_leg call_option.merge(strike: 155)
      expect(IB::Strangle.the_description(spread)).to include('Strangle')
    end
  end

  describe IB::Straddle do
    it 'returns parameters' do
      expect(IB::Straddle.parameters).to include('Required')
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg put_option
      spread.add_leg call_option
      expect(IB::Straddle.the_description(spread)).to include('Straddle')
    end
  end
end
