require 'spec_helper'

describe IB::Order do
  describe 'basic functionality' do
    it 'creates an order' do
      order = IB::Order.new(
        total_quantity: 100,
        limit_price: 150.0,
        order_type: :limit
      )
      expect(order).to be_a(IB::Order)
      expect(order.total_quantity).to eq(100)
      expect(order.limit_price).to eq(150.0)
    end

    it 'defaults order_type to limit' do
      order = IB::Order.new
      expect(order.order_type).to eq(:limit)
    end

    it 'defaults tif to day' do
      order = IB::Order.new
      expect(order.tif).to eq(:day)
    end
  end

  describe 'properties' do
    it 'has local_id' do
      order = IB::Order.new(local_id: 123)
      expect(order.local_id).to eq(123)
    end

    it 'has client_id' do
      order = IB::Order.new(client_id: 456)
      expect(order.client_id).to eq(456)
    end

    it 'has perm_id' do
      order = IB::Order.new(perm_id: 789)
      expect(order.perm_id).to eq(789)
    end

    it 'aliases quantity to total_quantity' do
      order = IB::Order.new(total_quantity: 100)
      expect(order.total_quantity).to eq(100)
    end
  end

  describe 'order types' do
    it 'creates market order' do
      order = IB::Order.new(order_type: :market)
      expect(order.order_type).to eq(:market)
    end

    it 'creates stop order' do
      order = IB::Order.new(order_type: :stop)
      expect(order.order_type).to eq(:stop)
    end

    it 'creates stop_limit order' do
      order = IB::Order.new(order_type: :stop_limit)
      expect(order.order_type).to eq(:stop_limit)
    end
  end

  describe 'time in force' do
    it 'defaults to day' do
      order = IB::Order.new
      expect(order.tif).to eq(:day)
    end

    it 'accepts good_til_canceled' do
      order = IB::Order.new(tif: :good_till_cancelled)
      expect(order.tif).to eq(:good_till_cancelled)
    end
  end

  describe 'complex orders' do
    it 'creates bracket order' do
      order = IB::Order.new(
        total_quantity: 100,
        limit_price: 150.0,
        parent_id: 100
      )
      expect(order.parent_id).to eq(100)
    end

    it 'creates OCA group order' do
      order = IB::Order.new(
        total_quantity: 100,
        oca_group: 'OCA_001'
      )
      expect(order.oca_group).to eq('OCA_001')
    end
  end

  describe 'serialization' do
    it 'serializes combo legs' do
      order = IB::Order.new
      bag = IB::Bag.new
      result = order.serialize_combo_legs(bag)
      expect(result).to be_an(Array)
    end

    it 'serializes main order fields' do
      order = IB::Order.new(
        total_quantity: 100,
        order_type: :limit,
        limit_price: 150.0
      )
      result = order.serialize_main_order_fields
      expect(result).to be_an(Array)
    end
  end
end
