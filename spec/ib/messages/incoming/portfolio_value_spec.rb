require 'main_helper'

describe IB::Messages::Incoming::PortfolioValue do
  context 'with hash data' do
    subject do
      IB::Messages::Incoming::PortfolioValue.new(
        version: 8,
        contract: { symbol: 'AAPL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
        portfolio_value: {
          position: 100,
          market_price: 150.50,
          market_value: 15050.00,
          average_cost: 145.00,
          unrealized_pnl: 550.00,
          realized_pnl: 0.00
        },
        account: 'DU123456'
      )
    end

    it 'parses position via portfolio_value model' do
      expect(subject.portfolio_value.position).to eq 100
    end

    it 'parses market_price via portfolio_value model' do
      expect(subject.portfolio_value.market_price).to eq BigDecimal('150.5')
    end

    its(:account) { is_expected.to eq 'DU123456' }
    its(:buffer) { is_expected.to be_empty }
  end

  context '#portfolio_value method caching' do
    let(:msg) do
      IB::Messages::Incoming::PortfolioValue.new(
        version: 8,
        contract: { symbol: 'AAPL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
        portfolio_value: { position: 10, market_price: 150.0, market_value: 1500.0, average_cost: 145.0, unrealized_pnl: 50.0, realized_pnl: 0.0 },
        account: 'DU123456'
      )
    end

    it 'creates IB::PortfolioValue model on first call' do
      pv = msg.portfolio_value
      expect(pv).to be_a IB::PortfolioValue
      expect(pv.position).to eq 10
    end

    it 'caches the PortfolioValue object on subsequent calls' do
      first_call = msg.portfolio_value
      second_call = msg.portfolio_value
      expect(first_call).to be(second_call)  # Same object reference
    end

    it 'sets contract and account on the model' do
      pv = msg.portfolio_value
      expect(pv.contract.symbol).to eq 'AAPL'
      expect(pv.account).to eq 'DU123456'
    end
  end

  context '#account_name method' do
    subject do
      IB::Messages::Incoming::PortfolioValue.new(
        version: 8,
        contract: { symbol: 'AAPL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' },
        portfolio_value: { position: 10 },
        account: 'DU999888'
      )
    end

    its(:account_name) { is_expected.to eq 'DU999888' }
  end
end
