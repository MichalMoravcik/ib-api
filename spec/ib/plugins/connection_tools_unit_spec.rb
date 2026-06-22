require 'spec_helper'

require File.expand_path('../../../../plugins/ib/connection-tools', __FILE__)

describe IB::ConnectionTools do
  let(:stub_socket) { IB::SocketStub.new }
  let(:connection) do
    c = IB::Connection.new
    c.socket = stub_socket
    c.instance_variable_set(:@connected, true)
    c
  end

  describe '#check_connection' do
    it 'returns true when CurrentTime message arrives within timeout' do
      allow(connection).to receive(:send_message)
      allow(connection).to receive(:subscribe).and_wrap_original do |m, *args, &block|
        id = m.call(*args, &block)
        Thread.new { sleep 0.01; connection.received[:CurrentTime] << :ok; block.call(double) if block }
        id
      end
      expect(connection.check_connection).to be true
    end

    it 'returns nil after retries without response' do
      allow(connection).to receive(:send_message)
      expect(connection.check_connection).to be_falsey
    end
  end

  describe '#try_connection' do
    it 'returns self on successful connection' do
      mod_method = IB::ConnectionTools.instance_method(:try_connection)
      allow(connection).to receive(:_try_connection)
      result = mod_method.bind(connection).call
      expect(result).to eq(connection)
    end

    it 'gives up after maximum retries' do
      mod_method = IB::ConnectionTools.instance_method(:try_connection)
      allow(connection).to receive(:sleep)
      allow(connection).to receive(:_try_connection).and_raise(Errno::ECONNREFUSED)
      result = mod_method.bind(connection).call(2)
      expect(result).to be false
    end
  end

  describe '#submit_to_alert_1102' do
    it 'is a protected method' do
      expect(connection.respond_to?(:submit_to_alert_1102, true)).to be true
    end

    it 'disconnects and checks connection on alert 2102' do
      expect(connection).to receive(:disconnect!)
      expect(connection).to receive(:check_connection)
      connection.send(:submit_to_alert_1102)
      alert = double('alert', id: 2102)
      connection.send(:subscribers)[IB::Messages::Incoming::Alert].values.first.call(alert)
    end

    it 'disconnects and checks connection on alert 1101' do
      expect(connection).to receive(:disconnect!)
      expect(connection).to receive(:check_connection)
      connection.send(:submit_to_alert_1102)
      alert = double('alert', id: 1101)
      connection.send(:subscribers)[IB::Messages::Incoming::Alert].values.first.call(alert)
    end

    it 'ignores other alerts' do
      expect(connection).not_to receive(:disconnect!)
      connection.send(:submit_to_alert_1102)
      alert = double('alert', id: 399)
      connection.send(:subscribers)[IB::Messages::Incoming::Alert].values.first.call(alert)
    end
  end

  describe '#check_connection retry paths' do
    it 'reconnects and retries after IB::Error' do
      send_count = 0
      allow(connection).to receive(:send_message) do
        send_count += 1
        raise IB::Error, 'not connected' if send_count == 1
      end
      allow(connection).to receive(:reconnect)
      subscribe_count = 0
      allow(connection).to receive(:subscribe).and_wrap_original do |m, *args, &block|
        subscribe_count += 1
        id = m.call(*args, &block)
        if subscribe_count == 2
          Thread.new { sleep 0.01; connection.received[:CurrentTime] << :ok; block.call(double) if block }
        end
        id
      end
      expect(connection.check_connection).to be true
    end

    it 'retries after IOError' do
      retry_count = 0
      allow(connection).to receive(:send_message) do
        retry_count += 1
        raise IOError, 'connection lost' if retry_count < 3
      end
      allow(connection).to receive(:subscribe).and_wrap_original do |m, *args, &block|
        id = m.call(*args, &block)
        Thread.new { sleep 0.01; connection.received[:CurrentTime] << :ok; block.call(double) if block }
        id
      end
      expect(connection.check_connection).to be true
    end

    it 'raises Workflow::NoTransitionAllowed after disconnect' do
      allow(connection).to receive(:send_message) { raise IB::Error, 'not connected' }
      allow(connection).to receive(:reconnect) { raise Workflow::NoTransitionAllowed, 'stuck' }
      expect { connection.check_connection }.to raise_error(Workflow::NoTransitionAllowed)
    end

    it 'exhausts retries and returns nil when no response' do
      allow(connection).to receive(:send_message)
      allow(connection).to receive(:subscribe).and_return(1)
      expect(connection.check_connection).to be_falsey
    end
  end

  describe '#try_connection error branches' do
    it 'raises TransmissionError on EHOSTUNREACH' do
      mod_method = IB::ConnectionTools.instance_method(:try_connection)
      allow(connection).to receive(:_try_connection).and_raise(Errno::EHOSTUNREACH, 'unreachable')
      expect { mod_method.bind(connection).call(2) }
        .to raise_error(IB::TransmissionError, /Cannot connect to specified host/)
    end

    it 'raises TransmissionError on SocketError' do
      mod_method = IB::ConnectionTools.instance_method(:try_connection)
      allow(connection).to receive(:_try_connection).and_raise(SocketError, 'unknown')
      expect { mod_method.bind(connection).call(2) }
        .to raise_error(IB::TransmissionError, /Wrong Adress/)
    end

    it 'returns self after logging IB::Error' do
      mod_method = IB::ConnectionTools.instance_method(:try_connection)
      allow(connection).to receive(:_try_connection).and_raise(IB::Error, 'boom')
      result = mod_method.bind(connection).call(2)
      expect(result).to eq(connection)
    end

    it 'retries with retry message on ECONNREFUSED after first attempt' do
      mod_method = IB::ConnectionTools.instance_method(:try_connection)
      allow(connection).to receive(:sleep)
      allow(connection).to receive(:_try_connection).and_raise(Errno::ECONNREFUSED)
      expect(connection).to receive(:logger).at_least(:once).and_call_original
      result = mod_method.bind(connection).call(2)
      expect(result).to be false
    end
  end
end
