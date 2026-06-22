require 'spec_helper'

describe IB::OptionDetail do
  let(:full_detail) do
    IB::OptionDetail.new(
      option: factory.create_option,
      delta: 0.5,
      gamma: 0.1,
      vega: 0.2,
      theta: -0.05,
      implied_volatility: 0.25,
      pv_dividend: 0.0,
      under_price: 160.0,
      option_price: 10.0,
      close_price: 9.5,
      open_tick: 1,
      bid_price: 9.9,
      ask_price: 10.1,
      prev_strike: 145.0,
      next_strike: 155.0,
      prev_expiry: '20251120',
      next_expiry: '20260117',
      updated_at: Time.now
    )
  end

  describe '#complete?' do
    it 'returns true when all core fields are present' do
      expect(full_detail).to be_complete
    end

    it 'returns false when a core field is missing' do
      detail = IB::OptionDetail.new(option: factory.create_option, delta: 0.5)
      expect(detail).not_to be_complete
    end
  end

  describe '#greeks?' do
    it 'returns true when greeks are present' do
      expect(full_detail).to be_greeks
    end

    it 'returns false when all greeks are missing' do
      detail = IB::OptionDetail.new(option: factory.create_option)
      expect(detail).not_to be_greeks
    end

    it 'returns true when some greeks are missing' do
      detail = IB::OptionDetail.new(
        option: factory.create_option,
        delta: 0.5,
        gamma: 0.1,
        vega: 0.2
      )
      expect(detail).to be_greeks
    end
  end

  describe '#prices?' do
    it 'returns true when price fields are present' do
      expect(full_detail).to be_prices
    end

    it 'returns false when a price field is missing' do
      detail = IB::OptionDetail.new(
        option: factory.create_option,
        implied_volatility: 0.25,
        under_price: 160.0
      )
      expect(detail).not_to be_prices
    end
  end

  describe '#iv' do
    it 'aliases implied_volatility' do
      expect(full_detail.iv).to eq(0.25)
    end
  end

  describe '#spread' do
    it 'returns the bid-ask spread' do
      expect(full_detail.spread).to eq(9.9 - 10.1)
    end
  end

  describe '#to_human' do
    it 'renders a complete detail' do
      expect(full_detail.to_human).to include('optionPrice')
      expect(full_detail.to_human).to include('delta')
      expect(full_detail.to_human).to include('160')
    end

    it 'renders greeks only when prices are absent' do
      detail = IB::OptionDetail.new(
        option: factory.create_option,
        delta: 0.5,
        gamma: 0.1,
        vega: 0.2,
        theta: -0.05
      )
      expect(detail.to_human).to include('Greeks')
      expect(detail.to_human).not_to include('optionPrice')
    end

    it 'renders prices and greeks when complete' do
      expect(full_detail.to_human).to include('optionPrice')
      expect(full_detail.to_human).to include('Greeks')
    end
  end

  describe '#table_header' do
    it 'returns the expected columns' do
      expect(full_detail.table_header).to eq(
        ['Greeks', 'price', 'impl. vola', 'dividend', 'delta', 'gamma', 'vega', 'theta']
      )
    end
  end

  describe '#table_row' do
    it 'returns a row with formatted values' do
      row = full_detail.table_row
      expect(row).to be_an(Array)
      expect(row.size).to eq(8)
      expect(row[1][:value]).to eq(format('%7.2f', 10.0))
    end

    it 'uses placeholders for nil values' do
      detail = IB::OptionDetail.new(option: factory.create_option)
      row = detail.table_row
      expect(row[1][:value]).to eq('--')
    end
  end
end
