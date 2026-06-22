require 'spec_helper'

describe IB::PortfolioValue do
  let(:contract) { factory.create_stock(symbol: 'AAPL') }
  let(:account) { IB::Account.new(account: 'DU123456') }
  let(:portfolio_value) do
    IB::PortfolioValue.new(
      account: account,
      contract: contract,
      position: 100,
      market_price: 175.5,
      market_value: 17550.0,
      average_cost: 150.0,
      unrealized_pnl: 2550.0,
      realized_pnl: 0.0
    )
  end

  describe '#==' do
    it 'considers two identical values equal' do
      other = IB::PortfolioValue.new(
        account: account,
        contract: contract,
        position: 100,
        market_price: 175.5,
        market_value: 17550.0,
        average_cost: 150.0,
        unrealized_pnl: 2550.0,
        realized_pnl: 0.0
      )
      expect(portfolio_value).to eq(other)
    end

    it 'distinguishes different positions' do
      other = IB::PortfolioValue.new(
        account: account,
        contract: contract,
        position: 200,
        market_price: 175.5,
        market_value: 35100.0,
        average_cost: 150.0,
        unrealized_pnl: 5100.0,
        realized_pnl: 0.0
      )
      expect(portfolio_value).not_to eq(other)
    end
  end

  describe '#to_human' do
    it 'includes the account, position, and market price' do
      expect(portfolio_value.to_human).to include('DU123456')
      expect(portfolio_value.to_human).to include('Pos=100')
      expect(portfolio_value.to_human).to include('175.5')
    end

    it 'includes unrealized PnL' do
      expect(portfolio_value.to_human).to include('2550')
      expect(portfolio_value.to_human).to include('unrealized')
    end

    it 'omits zero realized PnL' do
      expect(portfolio_value.to_human).not_to match(/ realized;/)
    end

    it 'includes realized PnL when present' do
      value = IB::PortfolioValue.new(
        account: account,
        contract: contract,
        position: 100,
        market_price: 175.5,
        market_value: 17550.0,
        average_cost: 150.0,
        unrealized_pnl: 0.0,
        realized_pnl: 500.0
      )
      expect(value.to_human).to include('500')
      expect(value.to_human).to include('realized')
    end

    it 'handles string account names' do
      value = IB::PortfolioValue.new(
        account: 'DU789',
        contract: contract,
        position: 100,
        market_price: 175.5,
        market_value: 17550.0,
        average_cost: 150.0,
        unrealized_pnl: 0.0,
        realized_pnl: 0.0
      )
      expect(value.to_human).to include('DU789')
    end
  end

  describe '#table_header' do
    it 'returns default headers without a block' do
      expect(portfolio_value.table_header).to eq(
        ['', '', 'pos', 'entry', 'market', 'value', 'unrealized', 'realized']
      )
    end

    it 'yields to include a custom label' do
      headers = portfolio_value.table_header { 'My Account' }
      expect(headers).to eq(
        ['', 'My Account', 'pos', 'entry', 'market', 'value', 'unrealized', 'realized']
      )
    end
  end

  describe '#table_row' do
    it 'returns formatted row values' do
      row = portfolio_value.table_row
      expect(row.size).to eq(8)
      expect(row[2][:value]).to eq(100)
      expect(row[5][:value]).to eq(17_550.0)
    end

    it 'uses contract multiplier when present' do
      contract_with_multiplier = factory.create_stock(symbol: 'AAPL', multiplier: 100)
      value = IB::PortfolioValue.new(
        contract: contract_with_multiplier,
        average_cost: 150.0
      )
      expect(value.table_row[3][:value]).to eq(1.5)
    end

    it 'uses 1 as divisor when multiplier is zero' do
      value = IB::PortfolioValue.new(
        contract: contract,
        average_cost: 150.0
      )
      expect(value.table_row[3][:value]).to eq(150.0)
    end

    it 'omits zero PnL values' do
      value = IB::PortfolioValue.new(
        contract: contract,
        position: 100,
        market_price: 175.5,
        market_value: 17550.0,
        average_cost: 150.0,
        unrealized_pnl: 0.0,
        realized_pnl: 0.0
      )
      row = value.table_row
      expect(row[6]).to eq('')
      expect(row[7]).to eq('')
    end

    it 'handles nil account' do
      value = IB::PortfolioValue.new(
        contract: contract,
        position: 100,
        market_price: 175.5,
        market_value: 17550.0,
        average_cost: 150.0,
        unrealized_pnl: 0.0,
        realized_pnl: 0.0
      )
      row = value.table_row
      expect(row[0]).to eq('')
    end
  end
end
