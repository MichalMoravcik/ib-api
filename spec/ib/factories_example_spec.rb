# frozen_string_literal: true

require 'spec_helper'

describe 'Factory Examples' do
  describe 'Contract Factories' do
    it 'creates a stock with defaults' do
      stock = IB::Test::Factory.create_stock
      expect(stock).to be_a(IB::Stock)
      expect(stock.symbol).to eq('AAPL')
      expect(stock.exchange).to eq('SMART')
      expect(stock.currency).to eq('USD')
    end

    it 'creates a stock with custom attributes' do
      stock = IB::Test::Factory.create_stock(symbol: 'MSFT', exchange: 'NASDAQ')
      expect(stock.symbol).to eq('MSFT')
      expect(stock.exchange).to eq('NASDAQ')
    end

    it 'creates an option with defaults' do
      option = IB::Test::Factory.create_option
      expect(option).to be_a(IB::Option)
      expect(option.symbol).to eq('AAPL')
      expect(option.strike).to eq(150.0)
      expect(option.expiry).to eq('20251220')
    end

    it 'creates a future with defaults' do
      future = IB::Test::Factory.create_future
      expect(future).to be_a(IB::Future)
      expect(future.symbol).to eq('ES')
      expect(future.expiry).to eq('202512')
    end

    it 'creates various contract types' do
      index = IB::Test::Factory.create_index
      expect(index).to be_a(IB::Index)

      forex = IB::Test::Factory.create_forex
      expect(forex).to be_a(IB::Forex)

      bond = IB::Test::Factory.create_bond
      expect(bond).to be_a(IB::Contract)
    end

    it 'creates a future option with defaults' do
      future_option = IB::Test::Factory.create_future_option
      expect(future_option).to be_a(IB::FutureOption)
      expect(future_option.symbol).to eq('ES')
      expect(future_option.strike).to eq(150.0)
      expect(future_option.expiry).to eq('20251220')
      expect(future_option.right).to eq(:call)
    end

    it 'creates a future option with custom attributes' do
      future_option = IB::Test::Factory.create_future_option(
        symbol: 'CL',
        strike: 80.0,
        expiry: '20250610',
        right: :put
      )
      expect(future_option.symbol).to eq('CL')
      expect(future_option.strike).to eq(80.0)
      expect(future_option.expiry).to eq('20250610')
      expect(future_option.right).to eq(:put)
    end

    it 'creates a spread with defaults' do
      spread = IB::Test::Factory.create_spread
      expect(spread).to be_a(IB::Spread)
      expect(spread.symbol).to eq('AAPL')
    end

    it 'creates a spread with custom attributes' do
      spread = IB::Test::Factory.create_spread(symbol: 'GOOGL')
      expect(spread.symbol).to eq('GOOGL')
    end

    it 'creates a stock spread with defaults' do
      stock_spread = IB::Test::Factory.create_stock_spread
      expect(stock_spread).to be_a(IB::Spread)
      expect(stock_spread.symbol).to eq('AAPL')
    end

    it 'creates a stock spread with custom attributes' do
      stock_spread = IB::Test::Factory.create_stock_spread(symbol: 'MSFT')
      expect(stock_spread.symbol).to eq('MSFT')
    end
  end

  describe 'Order Factories' do
    it 'creates a market order' do
      order = IB::Test::Factory.create_market_order
      expect(order).to be_a(IB::Order)
      expect(order.total_quantity).to eq(100)
    end

    it 'creates a limit order' do
      order = IB::Test::Factory.create_limit_order
      expect(order.limit_price).to eq(150.0)
    end

    it 'creates a limit order with custom price' do
      order = IB::Test::Factory.create_limit_order(
        action: 'BUY',
        quantity: 200,
        price: 155.50
      )
      expect(order.limit_price).to eq(155.50)
      expect(order.total_quantity).to eq(200)
    end

    it 'creates stop and stop-limit orders' do
      stop_order = IB::Test::Factory.create_stop_order
      expect(stop_order.aux_price).to eq(140.0)

      stop_limit = IB::Test::Factory.create_stop_limit_order
      expect(stop_limit.limit_price).to eq(150.0)
      expect(stop_limit.aux_price).to eq(140.0)
    end

    it 'creates a trailing stop order' do
      order = IB::Test::Factory.create_trailing_stop_order
      expect(order.order_type).to eq(:trailing_stop)
      expect(order.aux_price).to eq(1.0)
    end

    it 'creates a trailing stop limit order' do
      order = IB::Test::Factory.create_trailing_stop_limit_order(
        action: 'BUY',
        quantity: 100,
        price: 150.0,
        trail_amount: 1.0
      )
      expect(order.order_type).to eq(:trailing_limit)
      expect(order.limit_price).to eq(150.0)
      expect(order.aux_price).to eq(1.0)
    end

    it 'creates a pegged to stock order' do
      order = IB::Test::Factory.create_pegged_to_stock_order
      expect(order.order_type).to eq(:pegged_to_market)
      expect(order.total_quantity).to eq(100)
    end

    it 'creates a pegged to primary order' do
      order = IB::Test::Factory.create_pegged_to_primary_order
      expect(order.order_type).to eq(:pegged_to_primary)
    end

    it 'creates a relative order' do
      order = IB::Test::Factory.create_relative_order
      expect(order.order_type).to eq(:pegged_to_primary)
    end

    it 'creates a volatility order' do
      order = IB::Test::Factory.create_volatility_order
      expect(order.order_type).to eq(:volatility)
      expect(order.volatility).to eq(0.25)
    end
  end

  describe 'Generic Factory Method' do
    it 'creates objects using generic create method' do
      stock = IB::Test::Factory.create(:stock, symbol: 'GOOGL')
      expect(stock).to be_a(IB::Stock)
      expect(stock.symbol).to eq('GOOGL')

      option = IB::Test::Factory.create(:option, symbol: 'AMZN', strike: 100.0)
      expect(option).to be_a(IB::Option)
      expect(option.symbol).to eq('AMZN')

      order = IB::Test::Factory.create(:limit_order, price: 200.0)
      expect(order).to be_a(IB::Order)
      expect(order.limit_price).to eq(200.0)
    end

    it 'creates multiple objects' do
      stocks = IB::Test::Factory.create_list(:stock, 3)
      expect(stocks.length).to eq(3)
      expect(stocks.all? { |s| s.is_a?(IB::Stock) }).to be true
    end
  end

  describe 'Factory Helper Method' do
    it 'provides factory helper in specs' do
      stock = factory.create_stock(symbol: 'NFLX')
      expect(stock.symbol).to eq('NFLX')

      order = factory.create_market_order(action: 'SELL', quantity: 25)
      expect(order.total_quantity).to eq(25)
    end
  end

  describe 'Message Factories' do
    it 'creates contract_data_end message' do
      message = IB::Test::Factory.create_contract_data_end(request_id: 42)
      expect(message).to be_a(IB::Messages::Incoming::AbstractMessage)
      expect(message.instance_variable_get(:@data)[:request_id]).to eq(42)
    end

    it 'creates portfolio_value message' do
      message = IB::Test::Factory.create_portfolio_value(
        contract: { symbol: 'MSFT', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
        position: 100,
        market_price: 50.0
      )
      expect(message).to be_a(IB::Messages::Incoming::PortfolioValue)
      expect(message.contract.symbol).to eq('MSFT')
      expect(message.instance_variable_get(:@data)[:position]).to eq(100)
      expect(message.instance_variable_get(:@data)[:market_price]).to eq(50.0)
    end

    it 'creates position message' do
      message = IB::Test::Factory.create_position(
        account: 'DU999999',
        contract: { symbol: 'GOOGL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
        position: 50
      )
      expect(message).to be_a(IB::Messages::Incoming::PositionData)
      expect(message.contract.symbol).to eq('GOOGL')
      expect(message.instance_variable_get(:@data)[:account]).to eq('DU999999')
      expect(message.instance_variable_get(:@data)[:position]).to eq(50)
    end

    it 'creates market_data message as TickPrice' do
      message = IB::Test::Factory.create_market_data(
        request_id: 1,
        tick_type: 1,
        price: 150.25
      )
      expect(message).to be_a(IB::Messages::Incoming::TickPrice)
      expect(message.instance_variable_get(:@data)[:ticker_id]).to eq(1)
      expect(message.instance_variable_get(:@data)[:tick_type]).to eq(1)
      expect(message.instance_variable_get(:@data)[:price]).to eq(150.25)
    end

    it 'creates tick_price message' do
      message = IB::Test::Factory.create_tick_price(
        request_id: 5,
        tick_type: 2,
        price: 200.50
      )
      expect(message).to be_a(IB::Messages::Incoming::TickPrice)
      expect(message.instance_variable_get(:@data)[:ticker_id]).to eq(5)
      expect(message.instance_variable_get(:@data)[:tick_type]).to eq(2)
      expect(message.instance_variable_get(:@data)[:price]).to eq(200.50)
    end

    it 'creates tick_size message' do
      message = IB::Test::Factory.create_tick_size(
        request_id: 3,
        tick_type: 5,
        size: 100
      )
      expect(message).to be_a(IB::Messages::Incoming::TickSize)
      expect(message.instance_variable_get(:@data)[:ticker_id]).to eq(3)
      expect(message.instance_variable_get(:@data)[:tick_type]).to eq(5)
      expect(message.instance_variable_get(:@data)[:size]).to eq(100)
    end

    it 'creates error/alert message' do
      message = IB::Test::Factory.create_error(
        id: 100,
        error_code: 200,
        error_msg: 'Custom error message'
      )
      expect(message).to be_a(IB::Messages::Incoming::Alert)
      expect(message.instance_variable_get(:@data)[:error_id]).to eq(100)
      expect(message.instance_variable_get(:@data)[:code]).to eq(200)
      expect(message.instance_variable_get(:@data)[:message]).to eq('Custom error message')
    end

    it 'creates connection_status message' do
      message = IB::Test::Factory.create_connection_status(connected: false)
      expect(message).to be_a(IB::Messages::Incoming::AbstractMessage)
      expect(message.instance_variable_get(:@data)[:connected]).to eq(false)
    end

    it 'allows custom attributes via attrs' do
      message = IB::Test::Factory.create_portfolio_value(
        position: 200,
        market_price: 75.0,
        account: 'DU555555'
      )
      expect(message.instance_variable_get(:@data)[:position]).to eq(200)
      expect(message.instance_variable_get(:@data)[:account]).to eq('DU555555')
    end
  end

  describe 'Convenience Methods' do
    it 'creates aapl stock' do
      stock = IB::Test::Factory.aapl_stock
      expect(stock).to be_a(IB::Stock)
      expect(stock.symbol).to eq('AAPL')
    end

    it 'creates msft stock' do
      stock = IB::Test::Factory.msft_stock
      expect(stock).to be_a(IB::Stock)
      expect(stock.symbol).to eq('MSFT')
    end

    it 'creates goog stock' do
      stock = IB::Test::Factory.goog_stock
      expect(stock).to be_a(IB::Stock)
      expect(stock.symbol).to eq('GOOGL')
    end

    it 'creates popular stocks array' do
      stocks = IB::Test::Factory.popular_stocks
      expect(stocks).to be_a(Array)
      expect(stocks.length).to eq(3)
      expect(stocks[0].symbol).to eq('AAPL')
      expect(stocks[1].symbol).to eq('MSFT')
      expect(stocks[2].symbol).to eq('GOOGL')
    end

    it 'creates common options array' do
      options = IB::Test::Factory.common_options
      expect(options).to be_a(Array)
      expect(options.length).to eq(2)
      expect(options[0].symbol).to eq('AAPL')
      expect(options[0].right).to eq(:call)
      expect(options[1].symbol).to eq('MSFT')
      expect(options[1].right).to eq(:put)
    end
  end

  describe 'Generic Factory with New Types' do
    it 'creates trailing_stop_limit_order' do
      order = IB::Test::Factory.create(:trailing_stop_limit_order)
      expect(order).to be_a(IB::Order)
      expect(order.order_type).to eq(:trailing_limit)
    end

    it 'creates pegged_to_stock_order' do
      order = IB::Test::Factory.create(:pegged_to_stock_order)
      expect(order).to be_a(IB::Order)
      expect(order.order_type).to eq(:pegged_to_market)
    end

    it 'creates pegged_to_primary_order' do
      order = IB::Test::Factory.create(:pegged_to_primary_order)
      expect(order).to be_a(IB::Order)
      expect(order.order_type).to eq(:pegged_to_primary)
    end

    it 'creates relative_order' do
      order = IB::Test::Factory.create(:relative_order)
      expect(order).to be_a(IB::Order)
      expect(order.order_type).to eq(:pegged_to_primary)
    end

    it 'creates volatility_order' do
      order = IB::Test::Factory.create(:volatility_order)
      expect(order).to be_a(IB::Order)
      expect(order.order_type).to eq(:volatility)
    end

    it 'creates future_option' do
      option = IB::Test::Factory.create(:future_option)
      expect(option).to be_a(IB::Option)
      expect(option.sec_type).to eq(:futures_option)
    end

    it 'creates spread' do
      spread = IB::Test::Factory.create(:spread)
      expect(spread).to be_a(IB::Bag)
      expect(spread.sec_type).to eq(:bag)
    end

    it 'creates stock_spread' do
      spread = IB::Test::Factory.create(:stock_spread)
      expect(spread).to be_a(IB::Bag)
      expect(spread.symbol).to eq('AAPL')
    end
  end
end
