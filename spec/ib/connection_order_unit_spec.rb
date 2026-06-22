require 'spec_helper'

describe IB::Connection, 'order helpers (unit)' do
  let(:ib) do
    IB::Connection.new.tap do |c|
      c.instance_variable_set(:@socket, IB::SocketStub.new)
      c.instance_variable_set(:@connected, true)
      c.instance_variable_set(:@next_local_id, 100)
    end
  end

  let(:order) { IB::Order.new(action: :buy, total_quantity: 100, order_type: :limit, limit_price: 150) }
  let(:contract) { IB::Stock.new(symbol: 'AAPL', con_id: 123, exchange: 'SMART') }

  describe '#place_order' do
    before do
      allow(ib).to receive(:send_message)
    end

    it 'assigns client_id, local_id and increments next_local_id' do
      ib.place_order(order, contract)
      expect(order.client_id).to eq(ib.client_id)
      expect(order.local_id).to eq(100)
      expect(ib.next_local_id).to eq(101)
    end

    it 'raises if next_local_id is unknown' do
      ib.next_local_id = nil
      expect { ib.place_order(order, contract) }.to raise_error(RuntimeError)
    end

    it 'raises if order already has a local_id' do
      order.local_id = 50
      expect { ib.place_order(order, contract) }.to raise_error(RuntimeError)
    end
  end

  describe '#modify_order' do
    it 'raises if local_id is missing' do
      expect { ib.modify_order(order, contract) }.to raise_error(RuntimeError)
    end

    it 'sends PlaceOrder when local_id is present' do
      order.local_id = 100
      allow(ib).to receive(:send_message)
      ib.modify_order(order, contract)
      expect(ib).to have_received(:send_message).with(:PlaceOrder, hash_including(:order, :contract, :local_id))
    end
  end

  describe '#cancel_order' do
    it 'sends CancelOrder for each local id' do
      allow(ib).to receive(:send_message)
      ib.cancel_order(100, 101)
      expect(ib).to have_received(:send_message).with(:CancelOrder, hash_including(local_id: 100))
      expect(ib).to have_received(:send_message).with(:CancelOrder, hash_including(local_id: 101))
    end
  end

  describe '#received / #received?' do
    it 'returns empty array for unknown message type' do
      expect(ib.received[:NextValidId]).to eq([])
    end

    it 'reports received messages' do
      ib.received[:NextValidId] << 'msg'
      expect(ib.received?(:NextValidId)).to be true
    end
  end

  describe '#clear_received' do
    it 'clears all received messages' do
      ib.received[:NextValidId] << 'msg'
      ib.clear_received
      expect(ib.received[:NextValidId]).to be_empty
    end

    it 'clears only specified message types' do
      ib.received[:NextValidId] << 'msg'
      ib.received[:OrderStatus] << 'msg'
      ib.clear_received(:NextValidId)
      expect(ib.received[:NextValidId]).to be_empty
      expect(ib.received[:OrderStatus]).not_to be_empty
    end
  end

  describe '#wait_for' do
    it 'returns immediately if condition is already satisfied' do
      ib.received[:NextValidId] << 'msg'
      expect { ib.wait_for(:NextValidId) }.not_to raise_error
    end
  end
end
