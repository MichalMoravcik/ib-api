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
end
