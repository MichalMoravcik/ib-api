require 'main_helper'

# Edge-case tests for ScannerData message

RSpec.describe IB::Messages::Incoming::ScannerData do
  describe 'with zero count' do
    subject do
      described_class.new([
        3,    # version
        1,    # request_id
        0     # count - zero results
      ])
    end

    it 'creates empty results array' do
      expect(subject.results).to eq([])
    end

    it 'is valid (empty buffer)' do
      expect(subject).to be_valid
    end
  end

  describe 'with multiple results' do
    subject do
      described_class.new([
        3,    # version
        1,    # request_id
        2,    # count - two results
        1,    # rank 1
        12345, # con_id
        'AAPL', # symbol
        'STK',  # sec_type
        '',     # expiry
        0.0,    # strike
        '',     # right
        'SMART', # exchange
        'USD',   # currency
        'AAPL',  # local_symbol
        'NASDAQ', # market_name
        'NASDAQ', # trading_class
        '0.5',    # distance
        'SPX',    # benchmark
        'top gainers', # projection
        ''        # legs
      ])
    end

    it 'parses rank correctly' do
      expect(subject.results.first[:rank]).to eq 1
    end

    it 'parses contract fields correctly' do
      result = subject.results.first
      expect(result[:contract]).to be_a(IB::Contract)
      expect(result[:contract].con_id).to eq 12345
      expect(result[:contract].symbol).to eq 'AAPL'
    end

    it 'parses distance, benchmark, and projection' do
      result = subject.results.first
      expect(result[:distance]).to eq '0.5'
      expect(result[:benchmark]).to eq 'SPX'
      expect(result[:projection]).to eq 'top gainers'
    end
  end

  describe 'message_id and version' do
    it 'has correct message_id' do
      expect(described_class.message_id).to eq 20
    end

    it 'has correct version' do
      expect(described_class.version).to eq 3
    end
  end
end
