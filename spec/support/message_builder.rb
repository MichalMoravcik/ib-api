# frozen_string_literal: true

module IB
  class MessageBuilder
    def self.build_next_valid_id(local_id = 1)
      "!:\n#{local_id}\n"
    end

    def self.build_managed_accounts(account = 'DU4035278')
      # ManagedAccounts message (message type 6)
      "6:\n#{account}\n"
    end

    def self.build_open_order(order_id, _contract_symbol = 'EUR.USD', action = 'BUY')
      # OpenOrder message (message type 5)
      order_str = "#{order_id}:STK:EUR.USD:IDEALPRO:100:LIMIT:0:#{action}:DAY:0:1534897600:0:0:0:0:0"
      "5:\n#{order_str}\n"
    end

    def self.build_execution_data(order_id, exec_id = 1, shares = 100, price = '1.23456')
      # ExecutionData message (message type 7)
      exec_str = "#{order_id}:1:#{exec_id}:20230101-12:34:56:Filled:#{shares}:#{price}:0.005:USD:1"
      "7:\n#{exec_str}\n"
    end

    def self.build_commission_report(order_id, exec_id = 1, commission = '0.50')
      # CommissionReport message (message type 9)
      "9:\n#{order_id}:1:#{exec_id}:0:USD:#{commission}:0:0:\n"
    end

    def self.build_contract_data(_contract)
      # ContractData message (message type 42)
      "42:\n"
    end

    def self.build_empty_contract_data_end(request_id)
      # ContractDataEnd message (message type 43)
      "43:\n#{request_id}\n"
    end

    def self.build_server_version(version = IB::Messages::SERVER_VERSION, time = Time.now.utc.iso8601)
      # Server version message
      "!:\n#{version}\n#{time}\n"
    end
  end
end
