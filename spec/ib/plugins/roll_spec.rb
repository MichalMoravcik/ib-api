require 'spec_helper'

IB::Connection.current = Object.new.tap { |o| def o.activate_plugin(*); true; end; def o.logger; Logger.new(nil); end }
require_relative '../../../plugins/ib/verify'
require_relative '../../../plugins/ib/roll'
IB::Connection.current = nil

describe IB::RollFuture do
  let(:verified_future) do
    IB::Future.new(
      symbol: 'ES',
      exchange: 'GLOBEX',
      currency: 'USD',
      expiry: '202512',
      con_id: 12345,
      last_trading_day: '20251219'
    ).tap { |vf| allow(vf).to receive(:verify).and_return([vf]) }
  end

  let(:future) do
    f = IB::Future.new(
      symbol: 'ES',
      exchange: 'GLOBEX',
      currency: 'USD',
      expiry: '202509',
      con_id: 11111,
      last_trading_day: '20250919'
    )
    allow(f).to receive(:merge).and_return(verified_future)
    allow(f).to receive(:verify).and_return([verified_future])
    f
  end

  describe '#roll' do
    it 'rolls a future to a target expiry' do
      spread = future.roll(expiry: '202512')
      expect(spread).to be_an(IB::Spread)
      expect(spread.legs.size).to eq(2)
      expect(spread.description).to include('Roll')
      expect(spread.description).to include('ES')
    end

    it 'accepts a relative distance via :to' do
      spread = future.roll(to: '+3m')
      expect(spread).to be_an(IB::Spread)
      expect(spread.legs.size).to eq(2)
    end

    it 'raises an error when no args are given' do
      expect { future.roll }.to raise_error(IB::Error)
    end

    it 'raises an error when the target is not a future' do
      bad_future = IB::Future.new(symbol: 'ES', exchange: 'GLOBEX', currency: 'USD')
      allow(bad_future).to receive(:merge).and_return(IB::Stock.new(symbol: 'AAPL'))
      allow(bad_future).to receive(:verify).and_return([IB::Stock.new(symbol: 'AAPL')])
      expect { bad_future.roll(expiry: '202512') }.to raise_error(IB::Error)
    end
  end
end

describe IB::RollOption do
  let(:verified_option) do
    IB::Option.new(
      symbol: 'AAPL',
      exchange: 'SMART',
      currency: 'USD',
      expiry: '20251220',
      strike: 150.0,
      right: 'P',
      con_id: 12345
    ).tap do |vo|
      allow(vo).to receive(:verify).and_return([vo])
      allow(vo).to receive(:next_expiry).and_return(vo)
    end
  end

  let(:option) do
    o = IB::Option.new(
      symbol: 'AAPL',
      exchange: 'SMART',
      currency: 'USD',
      expiry: '20251120',
      strike: 155.0,
      right: 'P',
      con_id: 11111
    )
    allow(o).to receive(:merge).and_return(verified_option)
    allow(o).to receive(:verify).and_return([o])
    allow(o).to receive(:next_expiry).and_return(verified_option)
    o
  end

  describe '#roll' do
    it 'rolls an option to a target strike' do
      spread = option.roll(strike: 150.0)
      expect(spread).to be_an(IB::Spread)
      expect(spread.legs.size).to eq(2)
    end

    it 'rolls an option to a target expiry' do
      spread = option.roll(expiry: '20251220')
      expect(spread).to be_an(IB::Spread)
      expect(spread.legs.size).to eq(2)
    end

    it 'raises an error when no args are given' do
      expect { option.roll }.to raise_error(IB::Error)
    end

    it 'raises an error when the target is not an option' do
      bad_option = IB::Option.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD')
      stock = IB::Stock.new(symbol: 'AAPL', con_id: 12345)
      allow(stock).to receive(:verify).and_return([stock])
      allow(bad_option).to receive(:merge).and_return(stock)
      allow(bad_option).to receive(:next_expiry).and_return(stock)
      expect { bad_option.roll(strike: 150.0) }.to raise_error(NoMethodError)
    end
  end
end
