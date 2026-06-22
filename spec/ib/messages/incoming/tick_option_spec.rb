require 'spec_helper'

describe IB::Messages::Incoming::TickOption do
  describe 'instantiated with a data hash' do
    subject do
      IB::Messages::Incoming::TickOption.new(
        ticker_id: 1,
        tick_type: 10,
        tick_attribute: 0,
        implied_volatility: 0.25,
        delta: 0.5,
        option_price: 10.0,
        pv_dividend: 0.0,
        gamma: 0.1,
        vega: 0.2,
        theta: -0.05,
        under_price: 160.0
      )
    end

    it { is_expected.to be_an IB::Messages::Incoming::TickOption }

    it 'has a human-readable type' do
      expect(subject.type).to be_a(Symbol)
    end

    it 'returns the greeks as a hash' do
      expect(subject.greeks).to eq(
        delta: 0.5,
        gamma: 0.1,
        vega: 0.2,
        theta: -0.05
      )
    end

    it 'aliases iv to implied_volatility' do
      expect(subject.iv).to eq(0.25)
    end

    it 'detects present greeks' do
      expect(subject).to be_greeks
    end

    it 'renders a human-readable message' do
      expect(subject.to_human).to include('TickOption')
      expect(subject.to_human).to include('10.0')
      expect(subject.to_human).to include('0.25')
    end
  end

  describe 'with zero/placeholder values' do
    subject do
      IB::Messages::Incoming::TickOption.new(
        ticker_id: 1,
        tick_type: 11,
        tick_attribute: 0,
        implied_volatility: -1,
        delta: -2,
        option_price: -1,
        pv_dividend: -1,
        gamma: -2,
        vega: -2,
        theta: -2,
        under_price: -1
      )
    end

    it 'still detects greeks as present' do
      expect(subject).to be_greeks
    end

    it 'formats the human-readable message with placeholders' do
      expect(subject.to_human).to include('TickOption')
    end
  end

  describe 'with empty values' do
    subject do
      IB::Messages::Incoming::TickOption.new(
        ticker_id: 1,
        tick_type: 10,
        tick_attribute: 0
      )
    end

    it 'does not detect greeks when all are nil' do
      expect(subject).not_to be_greeks
    end
  end
end
