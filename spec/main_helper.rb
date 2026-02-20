require 'spec_helper'
require 'stringio'
require 'rspec/expectations'

## Logger helpers

def mock_logger
  @stdout = StringIO.new

  @logger = Logger.new(@stdout).tap do |logger|
    logger.formatter = proc do |_level, time, _prog, msg|
      "#{time.strftime('%H:%M:%S')} #{msg}\n"
    end
    logger.level = Logger::INFO
  end
end

def log_entries
  @stdout && @stdout.string.split(/\n/)
end

def should_log *patterns
  patterns.each do |pattern|
    expect(log_entries.any? { |entry| entry =~ pattern }).to be_truthy
  end
end

def should_not_log *patterns
  patterns.each do |pattern|
    expect(log_entries.any? { |entry| entry =~ pattern }).to be_falsey
  end
end

## Connection helper
# In gateway-mode ( establish_connection :gateway ) Connection#Clients is initialized,
#    open orders apperar Connection#Client#Orders
#
# otherwise anything works through the Connection#Received Hash

def establish_connection *plugins
  # Use stub socket for tests
  if ENV['TEST_ENV'] != 'real'
    require_relative 'support/socket_stub'
    require_relative 'support/message_builder'

    # Create connection with stub socket
    ib = IB::Connection.new(**OPTS[:connection].merge(logger: mock_logger))

    # Create and configure stub socket
    stub_socket = IB::SocketStub.new

    # Add basic responses
    stub_socket.add_message(IB::MessageBuilder.build_server_version)
    stub_socket.add_message(IB::MessageBuilder.build_next_valid_id(1))

    if plugins.map(&:to_s).any? do |p|
      p.include?('managed-accounts') || p.include?('process-orders') || p.include?('gateway')
    end
      stub_socket.add_message(IB::MessageBuilder.build_managed_accounts)
    end

    # Replace the socket with our stub
    ib.instance_variable_set(:@socket, stub_socket)
    ib.instance_variable_set(:@connected, true)
    ib.instance_variable_set(:@next_local_id, 1)

    # Initialize the parser with the stub socket
    require 'ib/raw_message_parser'
    parser = IB::RawMessageParser.new(stub_socket)
    ib.instance_variable_set(:@parser, parser)

    # Activate plugins
    %w[verify process-orders advanced-account].each do |plugin_name|
      ib.activate_plugin(plugin_name)
    rescue StandardError
      nil
    end

    accounts = [ACCOUNT]
  else
    # Real connection path (for reference)
    ib = nil
    accounts = nil
  end

  if ib
    unless accounts.include?(ACCOUNT)
      close_connection
      raise "Connected to wrong account ! Expected #{ACCOUNT} to be included in  #{accounts},  \n edit \'spec/config.yml\' "
    end
    puts "Performing tests with ClientId: #{ib.client_id}"
    OPTS[:account_verified] = true
  else
    OPTS[:account_verified] = false
    raise 'could not establish connection!'
  end
end

# Clear logs and message collector. Output may be silenced.
def clean_connection
  ib = IB::Connection.current
  return unless ib

  if OPTS[:verbose]
    puts(ib.received.map { |type, msg| [" #{type}:", msg.map(&:to_human)] })
    puts ' Logs:', log_entries if @stdout
  end
  @stdout.string = '' if @stdout
  ib.clear_received
end

def close_connection
  clean_connection
  ib = IB::Connection.current
  return if !ib || ib.workflow_state == 'disconnected'

  begin
    # Only disconnect if connection exists and is in a valid state
    ib.disconnect! unless %w[disconnected virgin].include?(ib.workflow_state)
  rescue StandardError => e
    # Silently ignore workflow errors during cleanup
    puts "Warning: Could not disconnect connection (state: #{ib.workflow_state}): #{e.message}" if OPTS[:verbose]
  end
end
