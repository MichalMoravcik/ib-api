require 'main_helper'

# Edge-case tests for MarketDepth message operations

RSpec.describe IB::Messages::Incoming::MarketDepth do
  describe 'operation' do
    it 'returns :insert for operation 0' do
      msg = described_class.new(['', 1, 0, 0, '100.0'.to_d, 50])
      expect(msg.operation).to eq :insert
    end

    it 'returns :update for operation 1' do
      msg = described_class.new(['', 1, 1, 0, '100.0'.to_d, 50])
      expect(msg.operation).to eq :update
    end

    it 'returns :delete for operation 2' do
      msg = described_class.new(['', 1, 2, 0, '100.0'.to_d, 50])
      expect(msg.operation).to eq :delete
    end

    it 'returns :delete for operation 3+ (fallback)' do
      msg = described_class.new(['', 1, 99, 0, '100.0'.to_d, 50])
      expect(msg.operation).to eq :delete
    end
  end

  describe 'side' do
    it 'returns :ask for side 0' do
      msg = described_class.new(['', 1, 0, 0, '100.0'.to_d, 50])
      expect(msg.side).to eq :ask
    end

    it 'returns :bid for side 1' do
      msg = described_class.new(['', 1, 0, 1, '100.0'.to_d, 50])
      expect(msg.side).to eq :bid
    end

    it 'returns :bid for side 2+ (fallback)' do
      msg = described_class.new(['', 1, 0, 99, '100.0'.to_d, 50])
      expect(msg.side).to eq :bid
    end
  end

  describe 'price and size' do
    it 'correctly parses decimal price' do
      msg = described_class.new(['', 1, 0, 0, '99.99'.to_d, 100])
      expect(msg.price).to eq 99.99
    end

    it 'handles integer size' do
      msg = described_class.new(['', 1, 0, 0, '100.0'.to_d, 100])
      expect(msg.size).to eq 100
    end
  end

  describe 'to_human' do
    it 'formats insert ask correctly' do
      msg = described_class.new(['', 1, 0, 0, '100.0'.to_d, 50])
      human = msg.to_human
      expect(human).to include('insert')
      expect(human).to include('ask')
    end

    it 'formats update bid correctly' do
      msg = described_class.new(['', 1, 1, 1, '99.0'.to_d, 75])
      human = msg.to_human
      expect(human).to include('update')
      expect(human).to include('bid')
    end
  end
end
