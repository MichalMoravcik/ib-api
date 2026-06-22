# frozen_string_literal: true

require 'spec_helper'

describe 'AdvancedAccount plugin' do
  let(:connection) do
    conn = IB::Connection.new
    allow(conn).to receive(:cancel_order)
    allow(conn).to receive(:place_order)
    conn
  end

  let(:account) do
    IB::Account.new(
      account: 'DU167348',
      alias: 'Demo',
      type: 'User'
    )
  end

  before do
    allow(IB::Connection).to receive(:current).and_return(connection)
    connection.activate_plugin(:advanced_account)
  end

  # ── shared factories ────────────────────────────────────────────
  let(:factory) { IB::Test::Factory }

  let(:stock_aapl) { factory.create_stock(symbol: 'AAPL', con_id: 12_345) }
  let(:stock_msft) { factory.create_stock(symbol: 'MSFT', con_id: 67_890) }

  let(:limit_order) do
    o = factory.create_limit_order(price: 150.0, quantity: 100)
    o.local_id = 10
    o.perm_id = 1000
    o.order_ref = 'my-ref'
    o.order_state = IB::OrderState.new(status: 'Submitted')
    o.contract = stock_aapl
    o
  end

  let(:market_order) do
    o = factory.create_market_order(quantity: 50)
    o.local_id = 11
    o.perm_id = 1001
    o.order_state = IB::OrderState.new(status: 'PreSubmitted')
    o.contract = stock_msft
    o
  end

  let(:cancelled_order) do
    o = factory.create_limit_order(price: 200.0, quantity: 10)
    o.local_id = 12
    o.order_state = IB::OrderState.new(status: 'Cancelled')
    o.contract = stock_aapl
    o
  end

  # ── account_data_scan ──────────────────────────────────────────
  describe '#account_data_scan' do
    let(:account_values) do
      [
        IB::AccountValue.new(key: 'CashBalance', currency: 'USD', value: '1000'),
        IB::AccountValue.new(key: 'CashBalance', currency: 'EUR', value: '500'),
        IB::AccountValue.new(key: 'NetLiquidation', currency: 'USD', value: '10000'),
        IB::AccountValue.new(key: 'DayTradesRemaining', currency: '', value: '3')
      ]
    end

    before { account.account_values = account_values }

    it 'filters account_values by a regex key only' do
      result = account.account_data_scan(/Cash/)
      expect(result.size).to eq(2)
      expect(result.map(&:currency)).to contain_exactly('USD', 'EUR')
    end

    it 'filters account_values by key and currency' do
      result = account.account_data_scan(/Cash/, 'USD')
      expect(result.size).to eq(1)
      expect(result.first.value).to eq('1000')
    end

    it 'returns an empty array when nothing matches' do
      result = account.account_data_scan(/NonExistent/)
      expect(result).to be_empty
    end

    it 'is case-sensitive by regex' do
      result = account.account_data_scan(/cash/)
      expect(result).to be_empty
    end

    it 'accepts plain strings and converts them to regex' do
      result = account.account_data_scan('Net')
      expect(result.size).to eq(1)
      expect(result.first.key).to eq('NetLiquidation')
    end
  end

  # ── locate_order ───────────────────────────────────────────────
  describe '#locate_order' do
    before { account.orders = [limit_order, market_order, cancelled_order] }

    it 'finds an order by local_id' do
      result = account.locate_order(local_id: 10)
      expect(result).to eq(limit_order)
    end

    it 'finds an order by perm_id' do
      result = account.locate_order(perm_id: 1001)
      expect(result).to eq(market_order)
    end

    it 'finds an order by order_ref' do
      result = account.locate_order(order_ref: 'my-ref')
      expect(result).to eq(limit_order)
    end

    it 'prefers local_id over perm_id when both are given' do
      result = account.locate_order(local_id: 10, perm_id: 1001)
      expect(result).to eq(limit_order)
    end

    it 'filters by status via regex' do
      result = account.locate_order(status: /Submitted/)
      expect(result).to eq(limit_order)
    end

    it 'filters by status using a string' do
      result = account.locate_order(status: 'PreSubmitted')
      expect(result).to eq(market_order)
    end

    it 'filters by contract' do
      result = account.locate_order(contract: stock_aapl)
      expect(result).to eq(limit_order)
    end

    it 'filters by con_id' do
      result = account.locate_order(con_id: 67_890)
      expect(result).to eq(market_order)
    end

    it 'returns nil when no order matches' do
      result = account.locate_order(local_id: 999)
      expect(result).to be_nil
    end

    it 'returns the last order when status is blank' do
      account.orders = [limit_order, cancelled_order]
      result = account.locate_order(status: nil)
      expect(result).to eq(cancelled_order)
    end

    it 'returns nil when local_id is zero' do
      result = account.locate_order(local_id: 0)
      expect(result).to be_nil
    end

    it 'selects all orders when no search key is given' do
      result = account.locate_order(status: nil)
      expect(result).to eq(cancelled_order)
    end
  end

  # ── locate_contract ────────────────────────────────────────────
  describe '#locate_contract' do
    before { account.contracts = [stock_aapl, stock_msft] }

    it 'finds a contract by con_id' do
      result = account.locate_contract(12_345)
      expect(result).to eq(stock_aapl)
    end

    it 'returns nil when no contract matches' do
      result = account.locate_contract(999)
      expect(result).to be_nil
    end
  end

  # ── cancel ─────────────────────────────────────────────────────
  describe '#cancel' do
    it 'delegates to Connection.current.cancel_order with the local_id' do
      order = limit_order
      expect(connection).to receive(:cancel_order).with(10)
      account.cancel(order: order)
    end
  end

  # ── complex_position ───────────────────────────────────────────
  describe '#complex_position' do
    let(:pv_aapl) do
      IB::PortfolioValue.new(
        contract: stock_aapl,
        position: 10,
        market_price: 150.0,
        average_cost: 145.0
      )
    end

    before do
      account.focuses = {
        'WatchlistA' => [
          [stock_aapl, pv_aapl]
        ]
      }
    end

    it 'returns the contract for a matching con_id' do
      result = account.complex_position(12_345)
      expect(result).to eq(stock_aapl)
    end

    it 'returns nil when no complex position is found' do
      result = account.complex_position(99_999)
      expect(result).to be_nil
    end

    it 'accepts a contract object and extracts con_id' do
      result = account.complex_position(stock_aapl)
      expect(result).to eq(stock_aapl)
    end
  end
end
