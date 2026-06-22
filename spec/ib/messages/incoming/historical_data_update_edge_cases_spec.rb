require 'main_helper'

# Edge-case tests for HistoricalDataUpdate message

RSpec.describe IB::Messages::Incoming::HistoricalDataUpdate do
  describe 'basic parsing' do
    subject do
      described_class.new([
        0,          # version
        1,          # request_id
        5,          # count
        1609459200, # bar time
        100.50,     # open
        100.75,     # close
        101.00,     # high
        99.50,      # low
        1000,       # volume
        100.60      # wap
      ])
    end

    it 'parses request_id correctly' do
      expect(subject.request_id).to eq 1
    end

    it 'parses count correctly' do
      expect(subject.count).to eq 5
    end
  end

  describe 'bar accessor' do
    subject do
      described_class.new([
        0,          # version
        1,          # request_id
        1,          # count
        1609459200, # bar time
        100.50,     # open
        100.75,     # close
        101.00,     # high
        99.50,      # low
        1000,       # volume
        100.60      # wap
      ])
    end

    it 'returns an IB::Bar object' do
      expect(subject.bar).to be_a(IB::Bar)
    end

    it 'caches the bar object' do
      bar1 = subject.bar
      bar2 = subject.bar
      expect(bar1).to be(bar2)
    end
  end

  describe 'to_human' do
    subject do
      described_class.new([
        0,          # version
        42,         # request_id
        1,          # count
        1609459200, # bar time
        100.50,     # open
        100.75,     # close
        101.00,     # high
        99.50,      # low
        1000,       # volume
        100.60      # wap
      ])
    end

    it 'includes request_id and bar info' do
      human = subject.to_human
      expect(human).to include('HistDataUpdate')
      expect(human).to include('42')
    end
  end
end
