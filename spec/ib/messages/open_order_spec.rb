require 'spec_helper'

describe IB::Messages::Incoming::OpenOrder do
  let(:message) do
    IB::Messages::Incoming::OpenOrder.new(
      order_id: 1,
      contract: { symbol: 'AAPL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
      order: {
        local_id: 1,
        client_id: 2,
        perm_id: 123,
        parent_id: 0,
        action: 'BUY',
        total_quantity: 100,
        order_type: 'LMT',
        limit_price: 150.0,
        tif: 'DAY'
      },
      order_state: { status: 'PreSubmitted' }
    )
  end

  it 'has correct message id' do
    expect(message.message_id).to eq(5)
  end

  it 'exposes order accessors' do
    expect(message.local_id).to eq(1)
    expect(message.client_id).to eq(2)
    expect(message.perm_id).to eq(123)
    expect(message.parent_id).to be_zero
    expect(message.status).to eq('PreSubmitted')
  end

  it 'aliases order_id to local_id' do
    expect(message.order_id).to eq(message.local_id)
  end

  it 'builds contract' do
    expect(message.contract).to be_a(IB::Contract)
    expect(message.contract.symbol).to eq('AAPL')
  end

  it 'builds order with order_state' do
    expect(message.order).to be_a(IB::Order)
    expect(message.order.local_id).to eq(1)
    expect(message.order.order_state).to be_a(IB::OrderState)
  end

  it 'returns empty conditions by default' do
    expect(message.conditions).to eq([])
  end

  it 'has human-readable output' do
    expect(message.to_human).to include('OpenOrder')
    expect(message.to_human).to include('AAPL')
  end

  describe '#filled?' do
    it 'returns false for empty strings' do
      expect(message.filled?('')).to be false
    end

    it 'returns true for positive numbers' do
      expect(message.filled?(1.5)).to be true
    end

    it 'returns truthiness for arbitrary values' do
      expect(message.filled?(true)).to be true
    end
  end
end
