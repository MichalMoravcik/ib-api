require 'spec_helper'

describe IB::Messages::Outgoing::PlaceOrder do
  let(:order) do
    IB::Order.new(
      total_quantity: 100,
      limit_price: 150.0,
      order_type: :limit,
      action: :buy,
      tif: :day,
      account: 'U12345'
    )
  end

  let(:contract) { IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD') }

  let(:message) { IB::Messages::Outgoing::PlaceOrder.new(order: order, contract: contract, local_id: 1) }

  before do
    allow(IB::Connection).to receive(:current).and_return(double(server_version: 165))
  end

  describe '#encode' do
    it 'starts with message id and version' do
      encoded = message.encode
      expect(encoded[0][0]).to eq(3)
      expect(encoded[0][1]).to eq(1)
      expect(encoded[0][2]).to eq([])
    end

    it 'includes local id and contract fields' do
      encoded = message.encode.flatten(2)
      expect(encoded).to include(1)
      expect(encoded).to include('AAPL')
      expect(encoded).to include('STK')
    end

    it 'includes order fields' do
      encoded = message.encode.flatten(2)
      expect(encoded).to include(100)
      expect(encoded).to include(150.0)
      expect(encoded).to include('BUY')
      expect(encoded).to include('LMT')
    end

    it 'uses order contract when contract is not a Contract' do
      order.instance_variable_set(:@contract, contract)
      msg = IB::Messages::Outgoing::PlaceOrder.new(order: order, contract: nil, local_id: 1)
      encoded = msg.encode.flatten(2)
      expect(encoded).to include('AAPL')
    end

    it 'raises when no valid contract is given' do
      msg = IB::Messages::Outgoing::PlaceOrder.new(order: order, contract: 'invalid', local_id: 1)
      order.instance_variable_set(:@contract, nil)
      expect { msg.encode }.to raise_error(RuntimeError, /contract has to be specified/)
    end
  end

  describe '#preprocess' do
    it 'converts booleans to 0/1' do
      allow(order).to receive(:all_or_none).and_return(true)
      preprocessed = message.preprocess.flatten(3)
      expect(preprocessed).to include(1)
    end
  end

  describe '#to_s' do
    it 'joins fields with hyphens' do
      expect(message.to_s).to include('3')
    end
  end
end
