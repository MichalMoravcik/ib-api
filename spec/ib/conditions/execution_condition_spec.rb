require 'spec_helper'

describe IB::ExecutionCondition do
  let(:contract) { factory.create_stock(symbol: 'AAPL') }

  describe '#condition_type' do
    it 'returns 5' do
      c = IB::ExecutionCondition.new
      expect(c.condition_type).to eq(5)
    end
  end

  describe '.make' do
    it 'creates a condition from a buffer' do
      buffer = double('buffer')
      allow(buffer).to receive(:read_string).and_return('o', 'STK', 'SMART', 'AAPL')
      allow(buffer).to receive(:read_int).and_return(1)

      c = IB::ExecutionCondition.make(buffer)
      expect(c).to be_an(IB::ExecutionCondition)
      expect(c.conjunction_connection).to eq(:or)
      expect(c.operator).to eq('>=')
      expect(c.contract.symbol).to eq('AAPL')
      expect(c.contract.sec_type).to eq(:stock)
      expect(c.contract.exchange).to eq('SMART')
    end
  end

  describe '#serialize' do
    it 'serializes sec_type, exchange, and symbol' do
      c = IB::ExecutionCondition.new(
        contract: contract,
        operator: '>=',
        conjunction_connection: :and
      )
      serialized = c.serialize
      expect(serialized).to include(5)
      expect(serialized).to include('STK')
      expect(serialized).to include('SMART')
      expect(serialized).to include('AAPL')
    end

    it 'uses primary_exchange when present' do
      c = IB::ExecutionCondition.new(
        contract: factory.create_stock(symbol: 'AAPL', primary_exchange: 'NYSE'),
        operator: '>=',
        conjunction_connection: :and
      )
      serialized = c.serialize
      expect(serialized).to include('NYSE')
    end
  end

  describe '.fabricate' do
    it 'creates a condition with a verified contract' do
      allow(IB::ExecutionCondition).to receive(:verify_contract_if_necessary).with(contract).and_return(contract)

      c = IB::ExecutionCondition.fabricate(contract)
      expect(c).to be_an(IB::ExecutionCondition)
      expect(c.contract).to eq(contract)
    end
  end
end
