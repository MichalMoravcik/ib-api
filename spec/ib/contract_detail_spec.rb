require 'spec_helper'

describe IB::ContractDetail do
  let(:contract) { factory.create_stock(symbol: 'AAPL') }
  let(:detail) do
    IB::ContractDetail.new(
      contract: contract,
      long_name: 'Apple Inc',
      market_name: 'NMS',
      category: 'Technology',
      industry: 'Consumer Electronics',
      subcategory: 'Phones',
      under_symbol: 'AAPL',
      under_sec_type: 'STK',
      under_con_id: 1,
      ev_multiplier: 1.0,
      md_size_multiplier: 100,
      min_tick: 0.01,
      price_magnifier: 1,
      valid_exchanges: 'SMART,ARCA',
      order_types: 'LMT,MKT',
      callable: false,
      puttable: false,
      convertible: true,
      coupon: 0.0,
      sec_id_list: { 'ISIN' => 'US0378331005' },
      time_zone: 'EST'
    )
  end

  describe '#default_attributes' do
    it 'sets sensible defaults' do
      d = IB::ContractDetail.new
      expect(d.coupon).to eq(0.0)
      expect(d.under_con_id).to eq(0)
      expect(d.min_tick).to eq(0)
      expect(d.ev_multiplier).to eq(0)
      expect(d.sec_id_list).to eq({})
      expect(d.callable).to be false
      expect(d.puttable).to be false
      expect(d.convertible).to be false
      expect(d.next_option_partial).to be false
    end
  end

  describe '#to_human' do
    it 'includes the long name' do
      expect(detail.to_human).to include('Apple Inc')
    end

    it 'includes market name when present' do
      expect(detail.to_human).to include('NMS')
    end

    it 'includes category information' do
      expect(detail.to_human).to include('Technology')
      expect(detail.to_human).to include('Consumer Electronics')
      expect(detail.to_human).to include('Phones')
    end

    it 'includes underlying info when under_con_id is non-zero' do
      expect(detail.to_human).to include('AAPL')
      expect(detail.to_human).to include('Underlying')
    end

    it 'includes ev_multiplier when present' do
      expect(detail.to_human).to include('ev_multiplier')
    end

    it 'includes convertible flag when true' do
      expect(detail.to_human).to include('convertible')
    end

    it 'omits coupon when zero' do
      expect(detail.to_human).not_to include('coupon:')
    end

    it 'includes coupon when positive' do
      d = IB::ContractDetail.new(coupon: 5.0)
      expect(d.to_human).to include('coupon')
    end

    it 'includes md_size_multiplier and min_tick' do
      expect(detail.to_human).to include('md_size_multiplier')
      expect(detail.to_human).to include('min_tick')
    end

    it 'includes puttable flag when present' do
      d = IB::ContractDetail.new(puttable: true)
      expect(d.to_human).to include('puttable')
    end

    it 'includes next_option_partial when present' do
      d = IB::ContractDetail.new(next_option_partial: true)
      expect(d.to_human).to include('next_option_partial')
    end

    it 'lists valid exchanges and order types' do
      expect(detail.to_human).to include('valid exchanges')
      expect(detail.to_human).to include('SMART,ARCA')
      expect(detail.to_human).to include('order types')
    end

    it 'skips sec_id_list when empty' do
      d = IB::ContractDetail.new
      expect(d.to_human).not_to include('sec_id-list')
    end
  end

  describe 'validations' do
    it 'is valid with a three-letter time zone' do
      expect(detail).to be_valid
    end

    it 'is invalid with a non-three-letter time zone' do
      d = IB::ContractDetail.new(time_zone: 'Eastern/Standard')
      expect(d).not_to be_valid
      expect(d.errors[:time_zone]).to include('should be XXX')
    end
  end

  describe 'aliases' do
    it 'aliases summary to contract' do
      expect(detail.summary).to eq(contract)
      new_contract = factory.create_stock(symbol: 'MSFT')
      detail.summary = new_contract
      expect(detail.contract).to eq(new_contract)
    end
  end
end
