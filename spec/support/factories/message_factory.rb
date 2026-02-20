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
    end
  end
end
