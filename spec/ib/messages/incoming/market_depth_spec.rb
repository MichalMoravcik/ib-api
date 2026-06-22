# frozen_string_literal: true

require 'main_helper'

describe IB::Messages::Incoming::MarketDepth do
  context 'Instantiated with hash data' do
    subject do
      IB::Messages::Incoming::MarketDepth.new(
        request_id: 1,
        position: 0,
        operation: 0,
        side: 0,
        price: '100.50',
        size: 100
      )
    end

    it 'parses position correctly' do
      expect(subject.position).to eq 0
    end

    it 'returns :ask for side 0' do
      expect(subject.side).to eq :ask
    end

    it 'returns :insert for operation 0' do
      expect(subject.operation).to eq :insert
    end

    its(:price) { is_expected.to eq '100.50' }
    its(:size) { is_expected.to eq 100 }
    its(:buffer) { is_expected.to be_empty }
  end

  context 'Bid side (side = 1)' do
    subject do
      IB::Messages::Incoming::MarketDepth.new(
        request_id: 1,
        position: 5,
        operation: 0,
        side: 1,
        price: '99.00',
        size: 50
      )
    end

    it 'returns :bid for side 1' do
      expect(subject.side).to eq :bid
    end
  end

  context 'Update operation (operation = 1)' do
    subject do
      IB::Messages::Incoming::MarketDepth.new(
        request_id: 1,
        position: 0,
        operation: 1,
        side: 0,
        price: '101.00',
        size: 200
      )
    end

    it 'returns :update for operation 1' do
      expect(subject.operation).to eq :update
    end
  end

  context 'Delete operation (operation = 2)' do
    subject do
      IB::Messages::Incoming::MarketDepth.new(
        request_id: 1,
        position: 0,
        operation: 2,
        side: 1,
        price: '0',
        size: 0
      )
    end

    it 'returns :delete for operation 2' do
      expect(subject.operation).to eq :delete
    end
  end

  context 'to_human output' do
    subject do
      IB::Messages::Incoming::MarketDepth.new(
        request_id: 1,
        position: 3,
        operation: 1,
        side: 0,
        price: '150.25',
        size: 75
      )
    end

    its(:to_human) do
      is_expected.to match(/MarketDepth/)
      is_expected.to match(/update/)
      is_expected.to match(/ask/)
      is_expected.to match(/150\.25/)
    end
  end
end
