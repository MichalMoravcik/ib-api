require 'spec_helper'

IB::Connection.new.activate_plugin 'order-prototypes'

RSpec.describe 'Order Prototypes (unit)' do
  describe IB::Limit do
    it 'builds a limit order' do
      order = IB::Limit.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:limit)
      expect(order.total_quantity).to eq(100)
      expect(order.limit_price).to eq(150)
    end

    it 'aliases price to limit_price' do
      order = IB::Limit.order action: :buy, size: 100, price: 150
      expect(order.limit_price).to eq(150)
    end

    it 'defaults to good_till_cancelled tif' do
      order = IB::Limit.order action: :buy, size: 100, price: 150
      expect(order.tif).to eq(:good_till_cancelled)
    end

    it 'serializes main order fields' do
      order = IB::Limit.order action: :buy, size: 100, price: 150
      expect(order.serialize_main_order_fields).to eq(['BUY', 100, 'LMT', 150, ''])
    end
  end

  describe IB::SimpleStop do
    it 'builds a stop order' do
      order = IB::SimpleStop.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:stop)
      expect(order.aux_price).to eq(150)
    end

    it 'serializes main order fields' do
      order = IB::SimpleStop.order action: :buy, size: 100, price: 150
      expect(order.serialize_main_order_fields).to eq(['BUY', 100, 'STP', '', 150])
    end
  end

  describe IB::StopLimit do
    it 'builds a stop limit order' do
      order = IB::StopLimit.order action: :buy, size: 100, price: 150, stop_price: 145
      expect(order.order_type).to eq(:stop_limit)
      expect(order.limit_price).to eq(150)
      expect(order.aux_price).to eq(145)
    end
  end

  describe IB::TrailingStop do
    it 'builds a trailing stop order' do
      order = IB::TrailingStop.order action: :buy, size: 100, price: 150, trailing_amount: 5
      expect(order.order_type).to eq(:trailing_stop)
      expect(order.trail_stop_price).to eq(150)
      expect(order.aux_price).to eq(5)
    end
  end

  describe IB::Market do
    it 'builds a market order' do
      order = IB::Market.order action: :buy, size: 100
      expect(order.order_type).to eq(:market)
      expect(order.tif).to eq(:day)
    end
  end

  describe IB::MarketIfTouched do
    it 'builds an MIT order' do
      order = IB::MarketIfTouched.order action: :buy, size: 100
      expect(order.order_type).to eq(:market_if_touched)
    end
  end

  describe IB::Pegged2Primary do
    it 'builds a pegged to primary order' do
      order = IB::Pegged2Primary.order action: :buy, size: 100, offset_amount: 0.5, price_cap: 150
      expect(order.order_type).to eq(:pegged_to_primary)
      expect(order.aux_price).to eq(0.5)
      expect(order.limit_price).to eq(150)
    end
  end

  describe IB::Pegged2Benchmark do
    it 'builds a pegged to benchmark order' do
      order = IB::Pegged2Benchmark.order action: :buy, size: 100,
                                         starting_price: 150,
                                         change_by: 0.5,
                                         reference_change_by: 1.0,
                                         reference: 123
      expect(order.order_type).to eq(:pegged_to_benchmark)
      expect(order.starting_price).to eq(150)
      expect(order.pegged_change_amount).to eq(0.5)
      expect(order.reference_change_amount).to eq(1.0)
      expect(order.reference_contract_id).to eq(123)
    end
  end

  describe IB::Discretionary do
    it 'builds a discretionary order' do
      order = IB::Discretionary.order action: :buy, size: 100, price: 150, dc: 0.5
      expect(order.order_type).to eq(:limit)
      expect(order.discretionary_amount).to eq(0.5)
    end
  end

  describe IB::LimitIfTouched do
    it 'builds a limit if touched order' do
      order = IB::LimitIfTouched.order action: :buy, size: 100, price: 150, trigger_price: 145
      expect(order.order_type).to eq(:limit_if_touched)
      expect(order.aux_price).to eq(145)
    end
  end

  describe IB::Sweep2Fill do
    it 'builds a sweep to fill order' do
      order = IB::Sweep2Fill.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:limit)
      expect(order.tif).to eq(:day)
      expect(order.sweep_to_fill).to be true
    end
  end

  describe IB::LimitOnClose do
    it 'builds a limit on close order' do
      order = IB::LimitOnClose.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:limit_on_close)
      expect(order.limit_price).to eq(150)
    end
  end

  describe IB::LimitOnOpen do
    it 'builds a limit on open order' do
      order = IB::LimitOnOpen.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:limit_on_open)
      expect(order.tif).to eq(:opening_price)
      expect(order.limit_price).to eq(150)
    end
  end

  describe 'OrderPrototype base' do
    it 'raises when required fields are missing' do
      expect { IB::Limit.order price: 150 }
        .to raise_error(IB::ArgumentError, /A necessary field is missing/)
    end

    it 'infers action from positive size' do
      order = IB::Limit.order size: 100, price: 150
      expect(order.action).to eq(:buy)
    end

    it 'infers sell action from negative size' do
      order = IB::Limit.order size: -100, price: 150
      expect(order.action).to eq(:sell)
    end

    it 'raises for zero size' do
      expect { IB::Limit.order size: 0, price: 150 }
        .to raise_error(RuntimeError, /Size = 0 is not possible/)
    end

    it 'returns parameters string' do
      expect(IB::Limit.parameters).to include('Required')
    end
  end

  describe IB::MarketOnClose do
    it 'builds a market on close order' do
      order = IB::MarketOnClose.order action: :buy, size: 100
      expect(order.order_type).to eq(:market_on_close)
      expect(order.tif).to eq(:day)
    end

    it 'returns a summary' do
      expect(IB::MarketOnClose.summary).to be_a(String)
    end
  end

  describe IB::MarketOnOpen do
    it 'builds a market on open order' do
      order = IB::MarketOnOpen.order action: :buy, size: 100
      expect(order.order_type).to eq(:market_on_close)
      expect(order.tif).to eq(:opening_price)
    end

    it 'returns a summary' do
      expect(IB::MarketOnOpen.summary).to be_a(String)
    end
  end

  describe IB::StopProtected do
    it 'builds a stop protected order' do
      order = IB::StopProtected.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:stop_protected)
      expect(order.aux_price).to eq(150)
    end

    it 'returns a summary' do
      expect(IB::StopProtected.summary).to be_a(String)
    end
  end

  describe IB::TrailingStopLimit do
    it 'builds a trailing stop limit order' do
      order = IB::TrailingStopLimit.order action: :buy, size: 100,
                                          trail_stop_price: 150,
                                          limit_price_offset: 145,
                                          trailing_percent: 5
      expect(order.order_type).to eq(:trailing_limit)
      expect(order.trail_stop_price).to eq(150)
      expect(order.limit_price_offset).to eq(145)
      expect(order.trailing_percent).to eq(5)
    end
  end

  describe IB::Pegged2Market do
    it 'builds a pegged to market order' do
      order = IB::Pegged2Market.order action: :buy, size: 100, price: 150, market_offset: 0.5
      expect(order.order_type).to eq(:pegged_to_market)
      expect(order.limit_price).to eq(150)
      expect(order.aux_price).to eq(0.5)
    end
  end

  describe IB::Pegged2Stock do
    it 'builds a pegged to stock order' do
      order = IB::Pegged2Stock.order action: :buy, size: 100,
                                     starting_price: 150,
                                     delta: 0.5
      expect(order.order_type).to eq(:pegged_to_market)
      expect(order.starting_price).to eq(150)
      expect(order.delta).to eq(0.5)
    end
  end

  describe IB::Adaptive do
    it 'builds an adaptive limit order' do
      order = IB::Adaptive.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:limit)
      expect(order.algo_strategy).to eq('Adaptive')
      expect(order.algo_params).to eq({ 'adaptivePriority' => 'Normal' })
    end
  end

  describe IB::Combo do
    it 'builds a combo order' do
      order = IB::Combo.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:limit)
      expect(order.combo_params).to eq([['NonGuaranteed', true]])
    end
  end

  describe IB::ForexLimit do
    it 'builds a forex limit order' do
      order = IB::ForexLimit.order action: :buy, size: 100, limit_price: 1.05, cash_qty: true
      expect(order.order_type).to eq(:limit)
      expect(order.cash_qty).to be true
    end
  end

  describe IB::AtAuction do
    it 'builds an at auction order' do
      order = IB::AtAuction.order action: :buy, size: 100, price: 150
      expect(order.order_type).to eq(:market_to_limit)
      expect(order.tif).to eq(:at_auction)
    end
  end

  describe IB::Volatility do
    it 'builds a volatility order' do
      order = IB::Volatility.order action: :buy, size: 100, volatility_percent: 25
      expect(order.order_type).to eq(:volatility)
      expect(order.volatility).to eq(25)
      expect(order.volatility_type).to eq(:annual)
    end
  end

  describe IB::Discretionary do
    it 'returns an example' do
      expect(IB::Discretionary.example).to be_a(String)
    end
  end

  describe 'metadata methods' do
    [
      IB::Limit, IB::Discretionary, IB::Sweep2Fill, IB::LimitIfTouched,
      IB::LimitOnClose, IB::LimitOnOpen, IB::SimpleStop, IB::StopLimit,
      IB::StopProtected, IB::TrailingStop, IB::TrailingStopLimit,
      IB::Market, IB::MarketIfTouched, IB::MarketOnClose, IB::MarketOnOpen,
      IB::Pegged2Primary, IB::Pegged2Market, IB::Pegged2Stock, IB::Pegged2Benchmark
    ].each do |mod|
      it "#{mod} returns a summary" do
        expect(mod.summary).to be_a(String)
      end
    end
  end
end
