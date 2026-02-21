require 'spec_helper'

describe IB::Spread do
  describe 'basic functionality' do
    it 'creates a spread' do
      spread = IB::Spread.new
      expect(spread).to be_a(IB::Spread)
    end
  end

  describe '.transform_distance' do
    it 'transforms date strings' do
      result = IB::Spread.transform_distance('202401', '202406')
      expect(result).to eq(202406)
    end

    it 'handles YYYYMMDD format' do
      result = IB::Spread.transform_distance('20240115', '20240615')
      expect(result).to eq(20240615)
    end

    it 'handles relative months' do
      result = IB::Spread.transform_distance('202401', '3m')
      expect(result).to eq('202404')
    end

    it 'handles relative weeks' do
      result = IB::Spread.transform_distance('20240115', '2w')
      expect(result).to be_a(String)
    end
  end

  describe '#to_human' do
    it 'returns description' do
      spread = IB::Spread.new
      spread.description = 'Test Spread'
      expect(spread.to_human).to eq('Test Spread')
    end
  end

  describe '#add_leg' do
    let(:stock) { IB::Stock.new(symbol: 'AAPL', con_id: 12345) }

    it 'adds a leg' do
      spread = IB::Spread.new
      spread.add_leg(stock, action: :buy)
      expect(spread.legs).to have(1).element
      expect(spread.combo_legs).to have(1).element
    end

    it 'raises error for non-contract' do
      spread = IB::Spread.new
      expect {
        spread.add_leg('invalid')
      }.to raise_error(IB::Error)
    end
  end

  describe '#essential' do
    it 'creates essential copy' do
      spread = IB::Spread.new
      spread.description = 'Test'
      copy = spread.essential
      expect(copy).to be_a(IB::Spread)
      expect(copy.description).to eq('Test')
    end
  end
end
