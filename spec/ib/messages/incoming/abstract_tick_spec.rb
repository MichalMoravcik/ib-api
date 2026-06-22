require 'main_helper'

describe IB::Messages::Incoming::AbstractTick do
  let(:tick_price_class) { IB::Messages::Incoming::TickPrice }

  context 'with hash data containing tick_type' do
    subject do
      tick_price_class.new(
        version: 6,
        ticker_id: 1,
        tick_type: 1,
        price: '100.50',
        size: 100,
        can_auto_execute: 1
      )
    end

    it 'returns the tick type symbol' do
      expect(subject.type).to eq :bid_price
    end

    its(:to_human) do
      is_expected.to match /TickPrice/
      is_expected.to match /bid_price/
    end

    it 'excludes version, ticker_id, and tick_type from to_human' do
      human = subject.to_human
      expect(human).not_to match(/version/)
      expect(human).not_to match(/ticker_id/)
      expect(human).not_to match(/tick_type/)
    end

    it 'includes price in to_human' do
      human = subject.to_human
      expect(human).to match(/100\.50/)
    end
  end

  context 'with different tick types' do
    subject do
      tick_price_class.new(
        version: 6,
        ticker_id: 2,
        tick_type: 2,
        price: '101.00',
        size: 50,
        can_auto_execute: 1
      )
    end

    it 'returns :ask_price for tick_type 2' do
      expect(subject.type).to eq :ask_price
    end
  end

  context 'the_data method' do
    subject do
      tick_price_class.new(
        version: 6,
        ticker_id: 1,
        tick_type: 1,
        price: '100.50',
        size: 100,
        can_auto_execute: 1
      )
    end

    it 'excludes version and ticker_id from the_data' do
      data = subject.the_data
      expect(data.keys).not_to include(:version)
      expect(data.keys).not_to include(:ticker_id)
      expect(data).to include(:tick_type)
      expect(data).to include(:price)
    end
  end
end
