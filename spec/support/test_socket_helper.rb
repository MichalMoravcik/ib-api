# frozen_string_literal: true

module TestSocketHelper
  def setup_test_socket(stub_config = {})
    # Get or create the connection
    ib = IB::Connection.current || IB::Connection.new(**OPTS[:connection])

    # Create a new stub socket
    stub_socket = IB::SocketStub.new

    # Configure with default responses
    configure_default_responses(stub_socket, stub_config)

    # Replace the socket
    ib.socket = stub_socket
    ib.instance_variable_set(:@connected, true)

    stub_socket
  end

  def configure_default_responses(socket, config)
    # Server version and handshake
    socket.add_message(IB::MessageBuilder.build_server_version)

    # Next valid ID
    socket.add_message(IB::MessageBuilder.build_next_valid_id(config[:next_local_id] || 1))

    # Managed accounts if needed
    socket.add_message(IB::MessageBuilder.build_managed_accounts(config[:account] || 'DU4035278'))

    # Add responses based on expected test scenarios
    return unless config[:expect_order_placement]

    socket.add_message(IB::MessageBuilder.build_open_order(config[:order_id] || 1, config[:symbol] || 'EUR.USD',
                                                           config[:action] || 'BUY'))
    socket.add_message(IB::MessageBuilder.build_execution_data(config[:order_id] || 1))
    socket.add_message(IB::MessageBuilder.build_commission_report(config[:order_id] || 1))
  end

  def add_response_to_socket(message_type, message)
    socket = IB::Connection.current&.socket
    return unless socket.is_a?(IB::SocketStub)

    case message_type.to_sym
    when :contract_data
      socket.add_message(IB::MessageBuilder.build_contract_data(message))
    when :contract_data_end
      socket.add_message(IB::MessageBuilder.build_empty_contract_data_end(message[:request_id]))
    else
      socket.add_message(message)
    end
  end
end
