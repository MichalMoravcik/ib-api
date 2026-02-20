# frozen_string_literal: true

module IB
  module Test
    class MockServer
      # Response builders for common IB message types
      module ResponseBuilders
        def self.build_contract_data(contract_id, contract_details)
          # ContractData message (message type 42)
          symbol = contract_details[:symbol] || 'AAPL'
          sec_type = contract_details[:sec_type] || 'STK'
          exchange = contract_details[:exchange] || 'SMART'
          currency = contract_details[:currency] || 'USD'

          "42:#{contract_id}:#{symbol}:#{sec_type}:#{exchange}:#{currency}"
        end

        def self.build_contract_data_end(request_id)
          # ContractDataEnd message (message type 43)
          "43:#{request_id}"
        end

        def self.build_order_status(order_id, status, filled, remaining)
          # OrderStatus message (message type 3)
          "3:#{order_id}:#{status}:#{filled}:#{remaining}"
        end

        def self.build_execution_data(exec_id, order_id, shares, price)
          # ExecutionData message (message type 7)
          "7:#{exec_id}:#{order_id}:#{shares}:#{price}"
        end

        def self.build_account_value(key, value, currency, account)
          # AccountValue message (message type 6)
          "6:#{key}:#{value}:#{currency}:#{account}"
        end

        def self.build_position(account, contract_id, position, avg_cost)
          # Position message (message type 41)
          "41:#{account}:#{contract_id}:#{position}:#{avg_cost}"
        end

        def self.build_market_data(ticker_id, field, price, size)
          # MarketData message (message type 1)
          "1:#{ticker_id}:#{field}:#{price}:#{size}"
        end

        def self.build_error_message(id, error_code, error_msg)
          # Error message (message type 4)
          "4:#{id}:#{error_code}:#{error_msg}"
        end
      end

      # Include response builders in the server
      include ResponseBuilders
    end
  end
end
