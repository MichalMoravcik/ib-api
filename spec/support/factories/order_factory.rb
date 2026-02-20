# frozen_string_literal: true

module IB
  module Test
    module OrderFactory
      def create_market_order(action: 'BUY', quantity: 100, **attrs)
        attributes = {
          action: action,
          total_quantity: quantity,
          order_type: 'MKT'
        }.merge(attrs)
        IB::Order.new(attributes)
      end

      def create_limit_order(action: 'BUY', quantity: 100, price: 150.0, **attrs)
        attributes = {
          action: action,
          total_quantity: quantity,
          order_type: 'LMT',
          limit_price: price
        }.merge(attrs)
        IB::Order.new(attributes)
      end

      def create_stop_order(action: 'BUY', quantity: 100, stop_price: 140.0, **attrs)
        attributes = {
          action: action,
          total_quantity: quantity,
          order_type: 'STP',
          aux_price: stop_price
        }.merge(attrs)
        IB::Order.new(attributes)
      end

      def create_stop_limit_order(action: 'BUY', quantity: 100, price: 150.0, stop_price: 140.0, **attrs)
        attributes = {
          action: action,
          total_quantity: quantity,
          order_type: 'STP LMT',
          limit_price: price,
          aux_price: stop_price
        }.merge(attrs)
        IB::Order.new(attributes)
      end

      def create_trailing_stop_order(action: 'BUY', quantity: 100, trail_amount: 1.0, **attrs)
        attributes = {
          action: action,
          total_quantity: quantity,
          order_type: 'TRAIL',
          trailing_amount: trail_amount
        }.merge(attrs)
        IB::Order.new(attributes)
      end
    end
  end
end
