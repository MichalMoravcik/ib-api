require 'spec_helper'

describe IB::TimeCondition do
  let(:condition) do
    IB::TimeCondition.new(
      operator: '>=',
      conjunction_connection: :and,
      time: DateTime.new(2026, 6, 22, 12, 0, 0)
    )
  end

  describe '#condition_type' do
    it 'returns 3' do
      expect(condition.condition_type).to eq(3)
    end
  end

  describe '.make' do
    it 'creates a condition from a buffer' do
      buffer = double('buffer')
      allow(buffer).to receive(:read_string).and_return('o')
      allow(buffer).to receive(:read_int).and_return(1)
      allow(buffer).to receive(:read_parse_date).and_return(DateTime.new(2026, 6, 22, 12, 0, 0))

      c = IB::TimeCondition.make(buffer)
      expect(c).to be_an(IB::TimeCondition)
      expect(c.conjunction_connection).to eq(:or)
      expect(c.operator).to eq('>=')
      expect(c.time).to eq(DateTime.new(2026, 6, 22, 12, 0, 0))
    end
  end

  describe '#serialize' do
    it 'serializes a DateTime with timezone' do
      serialized = condition.serialize
      expect(serialized).to include(3)
      expect(serialized.first).to eq(3)
      expect(serialized).to include('a')
      expect(serialized).to include(1)
      expect(serialized).to include('20260622 12:00:00 UTC')
    end

    it 'serializes a Date without timezone' do
      c = IB::TimeCondition.new(time: Date.new(2026, 6, 22))
      serialized = c.serialize
      expect(serialized.last).to include('20260622 00:00:00')
    end

    it 'serializes a String time as-is' do
      c = IB::TimeCondition.new(time: '20260622 12:00:00')
      serialized = c.serialize
      expect(serialized.last).to eq('20260622 12:00:00')
    end

    it 'converts yyyymmdd strings to DateTime' do
      c = IB::TimeCondition.new(time: '20260622')
      serialized = c.serialize
      expect(serialized.last).to include('20260622 00:00:00')
    end
  end

  describe '.fabricate' do
    it 'creates a condition with operator and time' do
      c = IB::TimeCondition.fabricate('>=', DateTime.new(2026, 6, 22, 12, 0, 0))
      expect(c).to be_an(IB::TimeCondition)
      expect(c.operator).to eq('>=')
      expect(c.time).to eq(DateTime.new(2026, 6, 22, 12, 0, 0))
    end
  end
end
