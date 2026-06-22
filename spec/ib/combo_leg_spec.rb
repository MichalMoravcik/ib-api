require 'spec_helper'

describe IB::ComboLeg do
  let(:leg) do
    IB::ComboLeg.new(
      con_id: 123,
      ratio: 2,
      side: :buy,
      exchange: 'SMART',
      open_close: :open,
      short_sale_slot: :default,
      exempt_code: -1
    )
  end

  describe 'defaults' do
    it 'sets sensible defaults' do
      leg = IB::ComboLeg.new
      expect(leg.con_id).to eq(0)
      expect(leg.ratio).to eq(1)
      expect(leg.side).to eq(:buy)
      expect(leg.open_close).to eq(:same)
      expect(leg.exchange).to eq('SMART')
      expect(leg.exempt_code).to eq(-1)
    end
  end

  describe 'validations' do
    it 'is valid with numeric ratio and con_id' do
      expect(leg).to be_valid
    end

    it 'rejects non-numeric ratio' do
      leg.ratio = 'abc'
      expect(leg).not_to be_valid
    end

    it 'enforces blank designated location' do
      leg.designated_location = 'LOC'
      expect(leg).not_to be_valid
    end
  end

  describe '#weight' do
    it 'returns positive ratio for buy' do
      expect(IB::ComboLeg.new(ratio: 3, side: :buy).weight).to eq(3)
    end

    it 'returns negative ratio for sell' do
      expect(IB::ComboLeg.new(ratio: 3, side: :sell).weight).to eq(-3)
    end
  end

  describe '#weight=' do
    it 'sets buy for positive values' do
      leg.weight = 5
      expect(leg.side).to eq(:buy)
      expect(leg.ratio).to eq(5)
    end

    it 'sets sell for negative values' do
      leg.weight = -4
      expect(leg.side).to eq(:sell)
      expect(leg.ratio).to eq(4)
    end
  end

  describe '#serialize' do
    it 'returns basic fields' do
      expect(leg.serialize).to eq([123, 2, 'BUY', 'SMART'])
    end

    it 'includes extended fields' do
      expect(leg.serialize(:extended)).to eq([123, 2, 'BUY', 'SMART', 1, 0, '', -1])
    end
  end

  describe '.build' do
    it 'builds from array' do
      built = IB::ComboLeg.build(123, 2, 'B', 'SMART', 1, 0, '', -1)
      expect(built.con_id).to eq(123)
      expect(built.ratio).to eq(2)
      expect(built.side).to eq(:buy)
      expect(built.exchange).to eq('SMART')
    end
  end

  describe '#to_human' do
    it 'describes the leg' do
      expect(leg.to_human).to include('buy')
      expect(leg.to_human).to include('123')
    end
  end

  describe '#==' do
    it 'matches identical legs' do
      other = IB::ComboLeg.new(
        con_id: 123,
        ratio: 2,
        side: :buy,
        exchange: 'SMART',
        open_close: :open,
        short_sale_slot: :default,
        exempt_code: -1
      )
      expect(leg).to eq(other)
    end

    it 'differs when con_id changes' do
      other = IB::ComboLeg.new(con_id: 999, ratio: 2, side: :buy, exchange: 'SMART')
      expect(leg).not_to eq(other)
    end
  end
end
