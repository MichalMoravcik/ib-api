require 'spec_helper'

RSpec.describe IB::Connection, 'deep unit coverage' do
  let(:ib) { IB::Connection.new }
  let(:stub_socket) { IB::SocketStub.new }

  def add_raw_message(socket, *fields)
    payload = fields.map(&:to_s).join("\0") + "\0"
    socket.add_message([payload.bytesize].pack('N') + payload)
  end

  before do
    allow(IB::Socket).to receive(:open).and_return(stub_socket)
    ib.try_connection!
    ib.instance_variable_set(:@connected, true)
    ib.instance_variable_set(:@received, true)
  end

  describe '#wait_for' do
    it 'returns when a message type is received' do
      ib.received[:NextValidId] << :dummy
      expect { ib.wait_for(:NextValidId) }.not_to raise_error
    end

    it 'returns when a custom condition is satisfied' do
      satisfied = false
      expect { ib.wait_for(0.1) { satisfied = true } }.not_to raise_error
    end
  end

  describe '#update_next_order_id' do
    it 'requests and stores next order id' do
      add_raw_message(stub_socket, 9, 1, 5)
      expect(ib.update_next_order_id).to eq(5)
      expect(ib.next_local_id).to eq(5)
    end
  end

  describe '#process_message' do
    it 'delivers a message to subscribers' do
      received = nil
      ib.subscribe(:NextValidId) { |msg| received = msg }
      add_raw_message(stub_socket, 9, 1, 5)
      ib.send(:process_message)
      expect(received).to be_a(IB::Messages::Incoming::NextValidId)
    end

    it 'stores message in received hash' do
      add_raw_message(stub_socket, 9, 1, 5)
      ib.send(:process_message)
      expect(ib.received?(:NextValidId)).to be true
    end
  end

  describe '#reconnect' do
    it 'returns early from nil workflow state' do
      ib2 = IB::Connection.new
      ib2.instance_variable_set(:@workflow_state, 'virgin')
      expect(ib2.reconnect).to be_nil
    end
  end

  describe 'error handling in #try_connection' do
    it 'rescues TransmissionError and retries connection' do
      allow(stub_socket).to receive(:initialising_handshake).and_raise(IB::TransmissionError.new('Test error'))
      allow(ib).to receive(:disconnect!)
      
      expect { ib.try_connection! }.to raise_error(IB::TransmissionError)
      expect(ib).to have_received(:disconnect!)
    end

    it 'raises error on server version mismatch' do
      parser = double('RawMessageParser')
      allow(parser).to receive(:each).and_yield([999, '2024-01-01'])
      allow(IB::RawMessageParser).to receive(:new).and_return(parser)
      stub_const('IB::MAX_CLIENT_VER', 165)
      
      expect { ib.try_connection! }.to raise_error(IB::Error)
    end
  end

  describe 'error handling in #process_messages' do
    it 'rescues Errno::ECONNRESET with connection reset by peer' do
      allow(Kernel).to receive(:select).and_raise(Errno::ECONNRESET.new('Connection reset by peer'))
      allow(ib.logger).to receive(:fatal)
      
      expect { ib.send(:process_messages, 50) }.to raise_error(IB::TransmissionError)
      expect(ib.logger).to have_received(:fatal).with('Connection reset by peer')
    end

    it 'rescues Errno::ECONNRESET with other error message' do
      allow(Kernel).to receive(:select).and_raise(Errno::ECONNRESET.new('Other error'))
      allow(ib.logger).to receive(:fatal)
      allow(Kernel).to receive(:exit).and_raise(SystemExit)
      
      expect { ib.send(:process_messages, 50) }.to raise_error(SystemExit)
      expect(ib.logger).to have_received(:fatal).with('Other error')
    end
  end

  describe 'error handling in #send_message' do
    it 'rescues Errno::EPIPE and reconnects' do
      allow(ib).to receive(:connected?).and_return(true)
      message = double('Message', data: {}, send_to: nil)
      allow(IB::Messages::Outgoing::RequestIds).to receive(:new).and_return(message)
      allow(message).to receive(:send_to).and_raise(Errno::EPIPE)
      allow(ib).to receive(:reconnect)
      
      expect { ib.send_message(:RequestIds) }.to raise_error(Errno::EPIPE)
      expect(ib).to have_received(:reconnect)
    end

    it 'raises error when not connected' do
      allow(ib).to receive(:connected?).and_return(false)
      expect { ib.send_message(:RequestIds) }.to raise_error(IB::TransmissionError)
    end
  end

  describe '#disconnect' do
    it 'stops reader thread if running' do
      ib.instance_variable_set(:@reader_running, true)
      ib.instance_variable_set(:@reader_thread, double('Thread', join: true))
      allow(stub_socket).to receive(:close)
      
      ib.send(:disconnect)
      
      expect(ib.instance_variable_get(:@reader_running)).to be false
      expect(stub_socket).to have_received(:close)
    end

    it 'closes socket without reader thread' do
      allow(stub_socket).to receive(:close)
      
      ib.send(:disconnect)
      
      expect(stub_socket).to have_received(:close)
      expect(ib.instance_variable_get(:@connected)).to be false
    end
  end

  describe '#start_reader' do
    it 'starts reader thread when not running' do
      ib.instance_variable_set(:@reader_running, false)
      ib.instance_variable_set(:@connected, true)
      
      thread = double('Thread', alive?: true)
      allow(Thread).to receive(:new).and_return(thread)
      
      ib.send(:start_reader)
      
      expect(ib.instance_variable_get(:@reader_running)).to be true
      expect(ib.instance_variable_get(:@reader_thread)).to eq(thread)
    end

    it 'rescues Errno::ECONNRESET and reconnects' do
      ib.instance_variable_set(:@reader_running, false)
      ib.instance_variable_set(:@connected, true)
      
      allow(Thread).to receive(:new).and_raise(Errno::ECONNRESET.new('Connection error'))
      allow(ib).to receive(:reconnect)
      allow(ib.logger).to receive(:fatal)
      
      ib.send(:start_reader)
      
      expect(ib).to have_received(:reconnect)
    end
  end

  describe 'subscription management' do
    it 'logs error when unsubscribe with invalid id' do
      allow(ib.logger).to receive(:error)
      ib.unsubscribe(999999)
      expect(ib.logger).to have_received(:error).with('No subscribers with id 999999')
    end

    it 'validates subscriber is a Proc' do
      expect { ib.subscribe(:NextValidId, 'not a proc') }.to raise_error(IB::ArgumentError)
    end

    it 'validates message class is valid' do
      expect { ib.subscribe(:InvalidMessageClass) }.to raise_error(IB::ArgumentError)
    end
  end

  describe '#clear_received' do
    it 'clears all received messages when no args' do
      ib.received[:NextValidId] << :dummy
      ib.received[:OrderStatus] << :dummy2
      
      ib.clear_received
      
      expect(ib.received[:NextValidId]).to be_empty
      expect(ib.received[:OrderStatus]).to be_empty
    end

    it 'clears specific message types' do
      ib.received[:NextValidId] << :dummy
      ib.received[:OrderStatus] << :dummy2
      
      ib.clear_received(:NextValidId)
      
      expect(ib.received[:NextValidId]).to be_empty
      expect(ib.received[:OrderStatus]).not_to be_empty
    end
  end

  describe 'workflow state transitions' do
    it 'handles reconnect from ready state' do
      ib.instance_variable_set(:@workflow_state, 'ready')
      ib.instance_variable_set(:@subscribers, {})
      allow(ib).to receive(:disconnect!)
      allow(ib).to receive(:try_connection!)
      
      ib.reconnect
      
      expect(ib).to have_received(:disconnect!)
      expect(ib).to have_received(:try_connection!)
    end

    it 'handles reconnect from account_based_orderflow state' do
      ib.instance_variable_set(:@workflow_state, 'account_based_orderflow')
      ib.instance_variable_set(:@subscribers, {})
      allow(ib).to receive(:disconnect!)
      allow(ib).to receive(:activate_managed_accounts!)
      allow(ib).to receive(:initialize_managed_accounts!)
      allow(ib).to receive(:initialize_order_handling!)
      
      ib.reconnect
      
      expect(ib).to have_received(:disconnect!)
      expect(ib).to have_received(:activate_managed_accounts!)
      expect(ib).to have_received(:initialize_managed_accounts!)
      expect(ib).to have_received(:initialize_order_handling!)
    end
  end
end