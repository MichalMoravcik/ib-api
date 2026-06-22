require 'main_helper'

# Edge-case tests for TickByTick message

RSpec.describe IB::Messages::Incoming::TickByTick do
  describe 'tick_type 0 (None)' do
    subject do
      described_class.new([
        0,          # ticker_id
        0,          # tick_type - None
        1609459200  # time
      ])
    end

    it 'parses basic fields correctly' do
      expect(subject.ticker_id).to eq 0
      expect(subject.tick_type).to eq 0
    end

    it 'has empty out_labels' do
      expect(subject.to_human).to eq '< TickByTick: >'
    end
  end

  describe 'tick_type 1 (Last)' do
    subject do
      described_class.new([
        1,          # ticker_id
        1,          # tick_type - Last
        1609459200, # time
        100.50,     # price
        75,         # size
        0,          # mask (no flags)
        'NYSE',     # exchange
        ''          # special_conditions
      ])
    end

    it 'parses last tick fields correctly' do
      expect(subject.price).to eq 100.50
      expect(subject.size).to eq 75
      expect(subject.exchange).to eq 'NYSE'
    end

    it 'has correct out_labels for Last' do
      expect(subject.to_human).to include('(Last)')
      expect(subject.to_human).to include('100.50')
    end
  end

  describe 'tick_type 2 (AllLast)' do
    subject do
      described_class.new([
        2,          # ticker_id
        2,          # tick_type - AllLast
        1609459200, # time
        100.50,     # price
        75,         # size
        3,          # mask (both PastLimit and Unreported)
        'NYSE',     # exchange
        ''          # special_conditions
      ])
    end

    it 'parses all last tick fields' do
      expect(subject.price).to eq 100.50
      expect(subject.size).to eq 75
      expect(subject.mask).to eq 3
    end

    it 'resolves mask correctly' do
      resolved = subject.resolve_mask
      expect(resolved).to eq [1, 1] # both bits set
    end
  end

  describe 'tick_type 3 (BidAsk)' do
    subject do
      described_class.new([
        3,          # ticker_id
        3,          # tick_type - BidAsk
        1609459200, # time
        100.00,     # bid_price
        100.50,     # ask_price
        50,         # bid_size
        75,         # ask_size
        2           # mask (BidPastHigh)
      ])
    end

    it 'parses bid/ask fields correctly' do
      expect(subject.bid_price).to eq 100.00
      expect(subject.ask_price).to eq 100.50
      expect(subject.bid_size).to eq 50
      expect(subject.ask_size).to eq 75
    end

    it 'has correct to_human format' do
      expect(subject.to_human).to include('(Bid/Ask)')
      expect(subject.to_human).to include('50 @ 100.0')
    end

    it 'resolves mask correctly' do
      resolved = subject.resolve_mask
      expect(resolved).to eq [0, 1]
    end
  end

  describe 'tick_type 4 (Midpoint)' do
    subject do
      described_class.new([
        4,          # ticker_id
        4,          # tick_type - Midpoint
        1609459200, # time
        100.25      # mid_point
      ])
    end

    it 'parses midpoint correctly' do
      expect(subject.mid_point).to eq 100.25
    end

    it 'has correct to_human format' do
      expect(subject.to_human).to include('(Midpoint)')
      expect(subject.to_human).to include('100.25')
    end
  end

  describe 'resolve_mask edge cases' do
    it 'handles mask 0 (no flags)' do
      msg = described_class.new([1, 1, 0, 100.50, 75, 0, 'NYSE', ''])
      expect(msg.resolve_mask).to eq [0, 0]
    end

    it 'handles mask 1 (only PastLimit)' do
      msg = described_class.new([1, 1, 0, 100.50, 75, 1, 'NYSE', ''])
      expect(msg.resolve_mask).to eq [1, 0]
    end

    it 'handles mask 2 (only Unreported)' do
      msg = described_class.new([1, 1, 0, 100.50, 75, 2, 'NYSE', ''])
      expect(msg.resolve_mask).to eq [0, 1]
    end

    it 'handles absent mask' do
      msg = described_class.new([4, 4, 0, 100.25])
      expect(msg.resolve_mask).to eq []
    end
  end

  describe 'message_id and version' do
    it 'has correct message_id' do
      expect(described_class.message_id).to eq 99
    end

    it 'has correct version' do
      expect(described_class.version).to eq 0
    end
  end
end
