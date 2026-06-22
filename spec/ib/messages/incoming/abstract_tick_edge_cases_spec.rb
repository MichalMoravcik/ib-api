require 'main_helper'

# Edge-case tests for AbstractTick

RSpec.describe IB::Messages::Incoming::AbstractTick do
  describe 'type' do
    let(:msg) { IB::Messages::Incoming::AbstractTick.new([1, 1]) }

    it 'returns symbol for valid tick type' do
      expect(msg.type).to be_a(Symbol)
    end
  end

  describe 'to_human' do
    let(:msg) { IB::Messages::Incoming::AbstractTick.new([1, 1, 100, 50.5]) }

    it 'excludes version, ticker_id, and tick_type from output' do
      human = msg.to_human
      expect(human).not_to include('version')
      expect(human).not_to include('ticker_id')
      expect(human).not_to include('tick_type')
    end
  end

  describe 'the_data' do
    let(:msg) { IB::Messages::Incoming::AbstractTick.new([1, 1, 100, 50.5]) }

    it 'excludes version and ticker_id from the_data' do
      data = msg.the_data
      expect(data.keys).not_to include(:version)
      expect(data.keys).not_to include(:ticker_id)
    end

    it 'includes other fields in the_data' do
      data = msg.the_data
      expect(data).to be_an(Hash)
    end
  end
end
