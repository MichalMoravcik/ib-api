# frozen_string_literal: true

require 'spec_helper'

describe 'Mock TWS Server' do
  Given(:mock_server) { IB::Test::MockServer.new(port: 7496) }

  after do
    mock_server.stop if mock_server.running?
  rescue StandardError => e
    puts "Error stopping server: #{e.message}"
  end

  describe 'server lifecycle' do
    it 'should start and stop successfully' do
      mock_server.start
      expect(mock_server).to be_running
      mock_server.stop
    end

    it 'should accept connections' do
      mock_server.start
      socket = TCPSocket.new('localhost', 7496)
      expect(socket).to be_a(TCPSocket)
      socket.close
      mock_server.stop
    end
  end

  describe 'protocol responses' do
    it 'should respond to version request' do
      mock_server.configure_default_responses
      mock_server.start
      socket = TCPSocket.new('localhost', 7496)
      socket.puts "API\Version\| 0\|"

      response = socket.gets
      expect(response).to include('10.8.1g')

      socket.close
      mock_server.stop
    end

    it 'should respond to managed accounts request' do
      mock_server.configure_default_responses
      mock_server.start
      socket = TCPSocket.new('localhost', 7496)
      socket.puts "ManagedAccounts\| 0\|"

      response = socket.gets
      expect(response).to include('U123456')

      socket.close
      mock_server.stop
    end

    it 'should respond to managed accounts request' do
      mock_server.configure_default_responses
      mock_server.start
      socket = TCPSocket.new('localhost', 7496)
      socket.puts "ManagedAccounts\| 0\|"

      response = socket.gets
      expect(response).to include('U123456')

      socket.close
      mock_server.stop
    end
  end

  describe 'configuration' do
    it 'should allow custom response handlers' do
      mock_server.on_message(/CustomMessage/) do |_message, _socket|
        'CustomResponse'
      end

      mock_server.start
      socket = TCPSocket.new('localhost', 7496)
      socket.puts "CustomMessage\| 0\|"

      response = socket.gets
      expect(response).to include('CustomResponse')

      socket.close
      mock_server.stop
    end
  end

  describe 'scenarios' do
    it 'should create fast response server' do
      fast_server = IB::Test::MockServer.for_scenario(:fast_response)
      expect(fast_server.latency).to eq(0)
      expect(fast_server.error_rate).to eq(0.0)
    end

    it 'should create unreliable server' do
      unreliable_server = IB::Test::MockServer.for_scenario(:unreliable)
      expect(unreliable_server.latency).to eq(50)
      expect(unreliable_server.error_rate).to eq(0.3)
    end
  end
end
