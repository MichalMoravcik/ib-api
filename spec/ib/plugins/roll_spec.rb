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

    context 'when option has zero con_id' do
      let(:unverified_option) do
        o = IB::Option.new(
          symbol: 'AAPL',
          exchange: 'SMART',
          currency: 'USD',
          expiry: '20251120',
          strike: 155.0,
          right: 'P',
          con_id: 0
        )
        allow(o).to receive(:merge).and_return(verified_option)
        allow(o).to receive(:verify).and_return([verified_option])
        allow(o).to receive(:next_expiry).and_return(verified_option)
        o
      end

      it 'uses verified result when con_id is zero' do
        spread = unverified_option.roll(strike: 150.0)
        expect(spread).to be_an(IB::Spread)
        expect(spread.legs.size).to eq(2)
      end
    end

    context 'when option cannot be verified' do
      let(:unverifiable_option) do
        o = IB::Option.new(
          symbol: 'AAPL',
          exchange: 'SMART',
          currency: 'USD',
          expiry: '20251120',
          strike: 155.0,
          right: 'P',
          con_id: 0  # zero triggers verify.first path
        )
        allow(o).to receive(:merge).and_return(verified_option)
        allow(o).to receive(:verify).and_return([IB::Stock.new(symbol: 'AAPL')])
        allow(o).to receive(:next_expiry).and_return(verified_option)
        o
      end

      it 'raises an error when option cannot be verified' do
        expect { unverifiable_option.roll(strike: 150.0) }.to raise_error(IB::Error, /cannot be verified/)
      end
    end
  end
end

describe IB::RollFuture do
  context 'with last_trading_day handling' do
    let(:future_with_ltd) do
      f = IB::Future.new(
        symbol: 'ES',
        exchange: 'GLOBEX',
        currency: 'USD',
        expiry: '202509',
        con_id: 11111,
        last_trading_day: '20250919'
      )
      allow(f).to receive(:merge).and_return(verified_future_with_ltd)
      allow(f).to receive(:verify).and_return([verified_future_with_ltd])
      f
    end

    let(:verified_future_with_ltd) do
      IB::Future.new(
        symbol: 'ES',
        exchange: 'GLOBEX',
        currency: 'USD',
        expiry: '202512',
        con_id: 12345,
        last_trading_day: '20251219'
      ).tap { |vf| allow(vf).to receive(:verify).and_return([vf]) }
    end

    it 'formats expiry using last_trading_day when present' do
      spread = future_with_ltd.roll(expiry: '202512')
      expect(spread.description).to include('Sep 25')
      expect(spread.description).to include('Dec 25')
    end
  end

  context 'without last_trading_day' do
    let(:future_without_ltd) do
      f = IB::Future.new(
        symbol: 'ES',
        exchange: 'GLOBEX',
        currency: 'USD',
        expiry: '202509',
        con_id: 11111
      )
      allow(f).to receive(:merge).and_return(verified_future_without_ltd)
      allow(f).to receive(:verify).and_return([verified_future_without_ltd])
      f
    end

    let(:verified_future_without_ltd) do
      IB::Future.new(
        symbol: 'ES',
        exchange: 'GLOBEX',
        currency: 'USD',
        expiry: '202512',
        con_id: 12345
      ).tap { |vf| allow(vf).to receive(:verify).and_return([vf]) }
    end

    it 'falls back to expiry when last_trading_day is missing' do
      spread = future_without_ltd.roll(expiry: '202512')
      expect(spread.description).to include('202509')
      expect(spread.description).to include('202512')
    end
  end

  context 'with empty last_trading_day' do
    let(:future_with_bad_ltd) do
      f = IB::Future.new(
        symbol: 'ES',
        exchange: 'GLOBEX',
        currency: 'USD',
        expiry: '202509',
        con_id: 11111,
        last_trading_day: ''
      )
      allow(f).to receive(:merge).and_return(verified_future_with_bad_ltd)
      allow(f).to receive(:verify).and_return([verified_future_with_bad_ltd])
      f
    end

    let(:verified_future_with_bad_ltd) do
      IB::Future.new(
        symbol: 'ES',
        exchange: 'GLOBEX',
        currency: 'USD',
        expiry: '202512',
        con_id: 12345,
        last_trading_day: ''
      ).tap { |vf| allow(vf).to receive(:verify).and_return([vf]) }
    end

    it 'uses expiry when last_trading_day is blank' do
      spread = future_with_bad_ltd.roll(expiry: '202512')
      expect(spread.description).to include('202509')
      expect(spread.description).to include('202512')
    end
  end
end
