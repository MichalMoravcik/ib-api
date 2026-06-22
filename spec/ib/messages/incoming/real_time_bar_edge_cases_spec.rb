require 'main_helper'

# Edge-case tests for RealTimeBar message

RSpec.describe IB::Messages::Incoming::RealTimeBar do
  describe 'bar accessor' do
    subject do
      described_class.new([
        3,          # version
        1,          # request_id
        1609459200, # time - Unix epoch
        100.50,     # open
        101.00,     # high
        99.50,      # low
        100.75,     # close
        1000,       # volume
        100.60,     # wap
        50          # trades
      ])
    end

    it 'returns an IB::Bar object' do
      expect(subject.bar).to be_a(IB::Bar)
    end

    it 'parses all bar fields correctly' do
      bar = subject.bar
      expect(bar.open).to eq 100.50
      expect(bar.high).to eq 101.00
      expect(bar.low).to eq 99.50
      expect(bar.close).to eq 100.75
      expect(bar.volume).to eq 1000
      expect(bar.wap).to eq 100.60
      expect(bar.trades).to eq 50
    end

    it 'caches the bar object' do
      bar1 = subject.bar
      bar2 = subject.bar
      expect(bar1).to be(bar2)
    end
  end

  describe 'request_id' do
    subject do
      described_class.new([
        3,          # version
        42,         # request_id
        1609459200, # time
        100.50,     # open
        101.00,     # high
        99.50,      # low
        100.75,     # close
        1000,       # volume
        100.60,     # wap
        50          # trades
      ])
    end

    it 'parses request_id correctly' do
      expect(subject.request_id).to eq 42
    end
  end

  describe 'to_human' do
    subject do
      described_class.new([
        3,          # version
        1,          # request_id
        1609459200, # time
        100.50,     # open
        101.00,     # high
        99.50,      # low
        100.75,     # close
        1000,       # volume
        100.60,     # wap
        50          # trades
      ])
    end

    it 'includes request_id and bar info' do
      human = subject.to_human
      expect(human).to include('RealTimeBar')
      expect(human).to include('1') # request_id
    end
  end
end
