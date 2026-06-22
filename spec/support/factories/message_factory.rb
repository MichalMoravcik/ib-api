# frozen_string_literal: true

module IB
  module Test
    module MessageFactory
      def create_open_order(order_id:, contract:, order:, state: nil, **attrs)
        IB::Messages::Incoming::OpenOrder.new(
          {
            order_id: order_id,
            contract: contract,
            order: order,
            order_state: state || IB::OrderState.new(status: 'Submitted')
          }.merge(attrs)
        )
      end

      def create_order_status(order_id:, status: 'Submitted', filled: 0, remaining: 100, **attrs)
        IB::Messages::Incoming::OrderStatus.new(
          {
            order_id: order_id,
            status: status,
            filled: filled,
            remaining: remaining,
            avg_fill_price: 0.0,
            last_fill_price: 0.0
          }.merge(attrs)
        )
      end

      def create_contract_data(contract_id:, contract_details: nil, **attrs)
        IB::Messages::Incoming::ContractData.new(
          {
            request_id: contract_id,
            contract_details: contract_details || IB::ContractDetail.new
          }.merge(attrs)
        )
      end

      def create_execution_data(exec_id:, order_id:, contract: nil, **attrs)
        IB::Messages::Incoming::ExecutionData.new(
          {
            order_id: order_id,
            execution: IB::Execution.new(
              exec_id: exec_id,
              order_id: order_id,
              shares: attrs[:shares] || 100,
              price: attrs[:price] || 150.0
            )
          }.merge(attrs)
        )
      end

      def create_account_value(key:, value:, currency: 'USD', account: 'DU123456', **attrs)
        IB::Messages::Incoming::AccountValue.new(
          {
            key: key,
            value: value,
            currency: currency,
            account: account
          }.merge(attrs)
        )
      end

      def create_contract_data_end(request_id: 1, **attrs)
        IB::Messages::Incoming::AbstractMessage.new(
          { request_id: request_id }.merge(attrs)
        )
      end

      def create_portfolio_value(contract: nil, position: 0, market_price: 0.0, **attrs)
        IB::Messages::Incoming::PortfolioValue.new(
          {
            contract: contract || { symbol: 'AAPL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
            position: position,
            market_price: market_price,
            market_value: position * market_price,
            average_cost: market_price,
            unrealized_pnl: 0.0,
            realized_pnl: 0.0,
            account: 'DU123456'
          }.merge(attrs)
        )
      end

      def create_position(account: 'DU123456', contract: nil, position: 0, **attrs)
        IB::Messages::Incoming::PositionData.new(
          {
            account: account,
            contract: contract || { symbol: 'AAPL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
            position: position,
            price: 0.0
          }.merge(attrs)
        )
      end

      def create_market_data(request_id: 1, tick_type: 1, price: 0.0, **attrs)
        IB::Messages::Incoming::TickPrice.new(
          {
            ticker_id: request_id,
            tick_type: tick_type,
            price: price,
            size: 0,
            can_auto_execute: 1
          }.merge(attrs)
        )
      end

      def create_tick_price(request_id: 1, tick_type: 1, price: 0.0, **attrs)
        IB::Messages::Incoming::TickPrice.new(
          {
            ticker_id: request_id,
            tick_type: tick_type,
            price: price,
            size: 0,
            can_auto_execute: 1
          }.merge(attrs)
        )
      end

      def create_tick_size(request_id: 1, tick_type: 1, size: 0, **attrs)
        IB::Messages::Incoming::TickSize.new(
          {
            ticker_id: request_id,
            tick_type: tick_type,
            size: size
          }.merge(attrs)
        )
      end

      def create_error(id: -1, error_code: 0, error_msg: 'Test error', **attrs)
        IB::Messages::Incoming::Alert.new(
          {
            error_id: id,
            code: error_code,
            message: error_msg
          }.merge(attrs)
        )
      end

      def create_connection_status(connected: true, **attrs)
        IB::Messages::Incoming::AbstractMessage.new(
          { connected: connected }.merge(attrs)
        )
      end
    end
  end
end
