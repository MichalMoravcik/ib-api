require 'spec_helper'

require_relative '../../conditions/ib/price_condition'
require_relative '../../conditions/ib/volume_condition'
require_relative '../../conditions/ib/percent_change_condition'

describe 'IB::PriceCondition' do
  it 'has condition type 1' do
    expect(IB::PriceCondition.new.condition_type).to eq(1)
  end

  it 'fabricates from a verified contract' do
    contract = IB::Stock.new(symbol: 'AAPL', con_id: 123, exchange: 'SMART')
    allow(contract).to receive(:verify).and_return([contract])
    condition = IB::PriceCondition.fabricate(contract, '>=', 150)
    expect(condition.price).to eq(150)
    expect(condition.operator).to eq('>=')
  end

  it 'raises for invalid operator' do
    contract = IB::Stock.new(symbol: 'AAPL')
    expect { IB::PriceCondition.fabricate(contract, '>', 150) }.to raise_error(IB::Error)
  end

  it 'makes from a buffer' do
    buffer = ['A', 1, '150.0', 123, 'SMART', 0]
    condition = IB::PriceCondition.make(buffer)
    expect(condition).to be_a(IB::PriceCondition)
    expect(condition.price).to eq(150)
  end
end

describe 'IB::VolumeCondition' do
  it 'has condition type 6' do
    expect(IB::VolumeCondition.new.condition_type).to eq(6)
  end

  it 'fabricates from a verified contract' do
    contract = IB::Stock.new(symbol: 'AAPL', con_id: 123, exchange: 'SMART')
    allow(contract).to receive(:verify).and_return([contract])
    condition = IB::VolumeCondition.fabricate(contract, '<=', 1000)
    expect(condition.volume).to eq(1000)
  end

  it 'makes from a buffer' do
    buffer = ['O', 0, '500', 123, 'SMART']
    condition = IB::VolumeCondition.make(buffer)
    expect(condition).to be_a(IB::VolumeCondition)
  end
end

describe 'IB::PercentChangeCondition' do
  it 'has condition type 7' do
    expect(IB::PercentChangeCondition.new.condition_type).to eq(7)
  end

  it 'fabricates from a verified contract' do
    contract = IB::Stock.new(symbol: 'AAPL', con_id: 123, exchange: 'SMART')
    allow(contract).to receive(:verify).and_return([contract])
    condition = IB::PercentChangeCondition.fabricate(contract, '>=', '5%')
    expect(condition.percent_change).to eq(5)
  end

  it 'makes from a buffer' do
    buffer = ['A', 1, '2.5', 123, 'SMART']
    condition = IB::PercentChangeCondition.make(buffer)
    expect(condition).to be_a(IB::PercentChangeCondition)
  end
end
