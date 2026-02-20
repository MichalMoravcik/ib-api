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
end
