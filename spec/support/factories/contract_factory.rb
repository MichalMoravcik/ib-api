# frozen_string_literal: true

module IB
  module Test
    module ContractFactory
      def create_stock(symbol: 'AAPL', **attrs)
        attributes = { symbol: symbol, sec_type: 'STK', exchange: 'SMART', currency: 'USD' }.merge(attrs)
        IB::Stock.new(attributes)
      end

      def create_option(symbol: 'AAPL', strike: 150.0, expiry: '20251220', right: 'C', **attrs)
        attributes = {
          symbol: symbol,
          sec_type: 'OPT',
          exchange: 'SMART',
          currency: 'USD',
          strike: strike,
          expiry: expiry,
          right: right
        }.merge(attrs)
        IB::Option.new(attributes)
      end

      def create_future(symbol: 'ES', expiry: '202512', **attrs)
        attributes = {
          symbol: symbol,
          sec_type: 'FUT',
          exchange: 'GLOBEX',
          currency: 'USD',
          expiry: expiry
        }.merge(attrs)
        IB::Future.new(attributes)
      end

      def create_index(symbol: 'SPX', **attrs)
        attributes = { symbol: symbol, sec_type: 'IND', exchange: 'CBOE', currency: 'USD' }.merge(attrs)
        IB::Index.new(attributes)
      end

      def create_cfd(symbol: 'AAPL', **attrs)
        attributes = { symbol: symbol, sec_type: 'CFD', exchange: 'SMART', currency: 'USD' }.merge(attrs)
        IB::Contract.new(attributes)
      end

      def create_commodity(symbol: 'XAUUSD', **attrs)
        attributes = { symbol: symbol, sec_type: 'CMDTY', exchange: 'SMART', currency: 'USD' }.merge(attrs)
        IB::Contract.new(attributes)
      end

      def create_bond(symbol: 'US30Y', **attrs)
        attributes = { symbol: symbol, sec_type: 'BOND', exchange: 'NYSE', currency: 'USD' }.merge(attrs)
        IB::Contract.new(attributes)
      end

      def create_forex(symbol: 'EUR', **attrs)
        attributes = { symbol: symbol, sec_type: 'CASH', exchange: 'IDEALPRO', currency: 'USD' }.merge(attrs)
        IB::Forex.new(attributes)
      end

      def create_combo(**attrs)
        attributes = { sec_type: 'BAG', exchange: 'SMART', currency: 'USD' }.merge(attrs)
        IB::Bag.new(attributes)
      end

      def create_future_option(symbol: 'ES', strike: 150.0, expiry: '20251220', right: :call, **attrs)
        attributes = {
          symbol: symbol,
          sec_type: 'FOP',
          exchange: 'GLOBEX',
          currency: 'USD',
          strike: strike,
          expiry: expiry,
          right: right
        }.merge(attrs)
        IB::FutureOption.new(attributes)
      end

      def create_spread(symbol: 'AAPL', **attrs)
        attributes = { symbol: symbol, sec_type: 'BAG', exchange: 'SMART', currency: 'USD' }.merge(attrs)
        IB::Spread.new(attributes)
      end

      def create_stock_spread(symbol: 'AAPL', **attrs)
        attributes = { symbol: symbol, sec_type: 'BAG', exchange: 'SMART', currency: 'USD' }.merge(attrs)
        IB::Spread.new(attributes)
      end
    end
  end
end
