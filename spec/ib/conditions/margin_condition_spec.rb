require 'spec_helper'

describe IB::MarginCondition do
  describe '#condition_type' do
    it 'returns 4' do
      c = IB::MarginCondition.new
      expect(c.condition_type).to eq(4)
    end
  end

  describe '.make' do
    it 'creates a condition from a buffer' do
      buffer = double('buffer')
      allow(buffer).to receive(:read_string).and_return('o')
      allow(buffer).to receive(:read_int).and_return(1, 50)

      c = IB::MarginCondition.make(buffer)
      expect(c).to be_an(IB::MarginCondition)
      expect(c.conjunction_connection).to eq(:or)
      expect(c.operator).to eq('>=')
      expect(c.percent).to eq(50)
    end
  end

  describe '#serialize' do
    it 'serializes operator and percent' do
      c = IB::MarginCondition.new(
        operator: 1,
        conjunction_connection: 'o',
        percent: 75
      )
      serialized = c.serialize
      expect(serialized).to include(4)
      expect(serialized).to include('o')
      expect(serialized).to include(1)
      expect(serialized).to include(75)
    end
  end

  describe '.fabricate' do
    it 'creates a condition with a valid operator' do
      c = IB::MarginCondition.fabricate('>=', 100)
      expect(c).to be_an(IB::MarginCondition)
      expect(c.operator).to eq('>=')
      expect(c.percent).to eq(100)
    end

    it 'raises an error with an invalid operator' do
      expect do
        IB::MarginCondition.fabricate('==', 100)
      end.to raise_error(IB::Error)
    end
  end
end
