# frozen_string_literal: true

require 'spec_helper'

describe 'ProcessOrders plugin' do
  let(:connection) do
    conn = IB::Connection.new(logger: Logger.new(StringIO.new))
    stub = IB::SocketStub.new
    stub.add_message("!:\n1\n")
    stub.add_message("9:\n1\n")
    conn.instance_variable_set(:@socket, stub)
    conn.instance_variable_set(:@connected, true)
    conn.instance_variable_set(:@next_local_id, 1)
    conn
  end

  let(:account) { IB::Account.new(account: 'DU123456', type: 'User') }
  let(:contract) { factory.create_stock(symbol: 'AAPL') }
  let(:order) do
    o = factory.create_limit_order(local_id: 1)
    o.contract = contract
    o.account = 'DU123456'
    o.order_state = IB::OrderState.new(status: 'Submitted')
    o
  end

  before do
    allow(IB::Connection).to receive(:current).and_return(connection)

    dummy = double('dummy_conn').as_null_object
    allow(IB::Connection).to receive(:current).and_return(dummy)
    require_relative '../../../plugins/ib/managed-accounts'
    require_relative '../../../plugins/ib/advanced-account'
    require_relative '../../../plugins/ib/process-orders'
    allow(IB::Connection).to receive(:current).and_return(connection)

    connection.class.send(:include, IB::ManagedAccounts)
    IB::Account.send(:include, IB::Advanced)
    connection.class.send(:include, IB::ProcessOrders)
    connection.send(:initialize_order_handling)

    account.orders = [order]
    account.contracts = [contract]
    account.portfolio_values = []
    connection.instance_variable_set(:@accounts, [account])
  end

  def subscribers
    connection.send(:subscribers)
  end

  after do
    Thread.list.each { |t| t.kill if t != Thread.current && t != Thread.main }
  end

  describe '#initialize_order_handling' do
    it 'registers subscribers for all required message types' do
      subs = subscribers
      expect(subs.keys).to include(IB::Messages::Incoming::CommissionReport)
      expect(subs.keys).to include(IB::Messages::Incoming::ExecutionData)
      expect(subs.keys).to include(IB::Messages::Incoming::OrderStatus)
      expect(subs.keys).to include(IB::Messages::Incoming::OpenOrder)
      expect(subs.keys).to include(IB::Messages::Incoming::OpenOrderEnd)
      expect(subs.keys).to include(IB::Messages::Incoming::NextValidId)
    end
  end

  describe 'OrderStatus handler' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::OrderStatus].values.first
    end

    let(:order_status_msg) do
      IB::Messages::Incoming::OrderStatus.new(
        order_state: {
          local_id: 1,
          status: 'Filled',
          filled: 100,
          remaining: 0,
          average_fill_price: 150.0,
          perm_id: 999,
          parent_id: 0,
          last_fill_price: 150.0,
          client_id: 1,
          why_held: '',
          market_cap_price: 0
        }
      )
    end

    it 'appends the new order state to the located order' do
      expect { subscriber.call(order_status_msg) }.to change { order.order_states.size }.by(1)
    end

    it 'logs a warning when the order cannot be located' do
      bad_msg = IB::Messages::Incoming::OrderStatus.new(
        order_state: {
          local_id: 99_999,
          status: 'Cancelled',
          filled: 0,
          remaining: 100,
          average_fill_price: 0,
          perm_id: 0,
          parent_id: 0,
          last_fill_price: 0,
          client_id: 1,
          why_held: '',
          market_cap_price: 0
        }
      )
      expect(connection.logger).to receive(:warn)
      subscriber.call(bad_msg)
    end
  end

  describe 'OpenOrder handler' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::OpenOrder].values.first
    end

    let(:open_order_msg) do
      IB::Messages::Incoming::OpenOrder.new(
        order_id: 1,
        contract: contract.attributes.merge(sec_type: 'STK'),
        order: order.attributes.merge(local_id: 1, perm_id: 999, client_id: 1, parent_id: 0),
        order_state: { status: 'Submitted' }
      )
    end

    it 'associates the contract with the account' do
      subscriber.call(open_order_msg)
      expect(account.contracts.map(&:symbol)).to include('AAPL')
    end

    it 'associates the order with the account by local_id' do
      account.orders = []
      subscriber.call(open_order_msg)
      expect(account.orders.map(&:local_id)).to include(1)
    end
  end

  describe 'OpenOrderEnd handler' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::OpenOrderEnd].values.first
    end

    it 'logs the OpenOrderEnd event' do
      msg = IB::Messages::Incoming::OpenOrderEnd.new({})
      expect(connection.logger).to receive(:debug)
      subscriber.call(msg)
    end
  end

  describe 'ExecutionData handler' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::ExecutionData].values.first
    end

    let(:execution_msg) do
      IB::Messages::Incoming::ExecutionData.new(
        order_id: 1,
        contract: contract.attributes.merge(sec_type: 'STK'),
        execution: {
          exec_id: 'EXEC001',
          local_id: 1,
          shares: 100,
          cumulative_quantity: 100,
          price: 150.0,
          average_price: 150.0,
          side: 'BOT',
          account_name: 'DU123456'
        }
      )
    end

    it 'stores the execution on the matched order' do
      expect { subscriber.call(execution_msg) }.to change { order.executions.size }.by(1)
    end

    context 'when execution fills the entire order' do
      it 'creates a portfolio value for the contract' do
        order.total_quantity = 100
        order.action = :buy
        subscriber.call(execution_msg)
        expect(account.portfolio_values).not_to be_empty
      end

      it 'updates an existing portfolio value instead of duplicating' do
        order.total_quantity = 100
        order.action = :buy
        account.portfolio_values << IB::PortfolioValue.new(position: 50, contract: contract)
        subscriber.call(execution_msg)
        positions = account.portfolio_values.select { |pv| pv.contract.con_id == contract.con_id }
        expect(positions.size).to eq(1)
        expect(positions.first.position).to eq(150)
      end
    end

    context 'when execution cannot be matched' do
      it 'logs a warning' do
        unmatched = IB::Messages::Incoming::ExecutionData.new(
          order_id: 99_999,
          contract: contract.attributes.merge(sec_type: 'STK'),
          execution: {
            exec_id: 'EXEC999',
            local_id: 99_999,
            shares: 10,
            cumulative_quantity: 10,
            price: 150.0,
            average_price: 150.0,
            side: 'BOT',
            account_name: 'DU123456'
          }
        )
        expect(connection.logger).to receive(:warn)
        subscriber.call(unmatched)
      end
    end
  end

  describe 'CommissionReport handler' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::CommissionReport].values.first
    end

    it 'logs commission info' do
      msg = IB::Messages::Incoming::CommissionReport.new(
        exec_id: 'EXEC001',
        commission: 2.5,
        currency: 'USD',
        realized_pnl: 10.0,
        yield: 0,
        yield_redemption_date: 0
      )
      expect(connection.logger).to receive(:info).with(/CommissionReport/)
      subscriber.call(msg)
    end
  end

  describe '#request_open_orders' do
    let(:open_queue) do
      q = Queue.new
      allow(q).to receive(:pop).and_return(true)
      allow(q).to receive(:close)
      allow(q).to receive(:closed?).and_return(false)
      q
    end

    before do
      allow(Queue).to receive(:new).and_return(open_queue)
      allow(Thread).to receive(:new).and_return(Thread.new { nil })
      allow(connection).to receive(:send_message)
      allow(connection).to receive(:subscribe).with(:OpenOrderEnd).and_return(99)
      allow(connection).to receive(:unsubscribe)
    end

    it 'clears existing orders before requesting' do
      account.orders = [order]
      connection.request_open_orders
      expect(account.orders).to be_empty
    end

    it 'sends RequestAllOpenOrders' do
      expect(connection).to receive(:send_message).with(:RequestAllOpenOrders)
      connection.request_open_orders
    end

    context 'when OpenOrderEnd times out' do
      let(:closed_queue) do
        q = Queue.new
        allow(q).to receive(:pop)
        allow(q).to receive(:close)
        allow(q).to receive(:closed?).and_return(true)
        q
      end

      before do
        allow(Queue).to receive(:new).and_return(closed_queue)
        allow(Thread).to receive(:new).and_return(Thread.new { nil })
        allow(connection).to receive(:subscribe).with(:OpenOrderEnd).and_return(99)
        allow(connection).to receive(:unsubscribe)
      end

      it 'logs a fatal read-only API warning' do
        expect(connection.logger).to receive(:fatal).at_least(:once)
        connection.request_open_orders
      end
    end
  end

  describe '#update_orders alias' do
    it 'aliases to request_open_orders' do
      expect(connection.method(:update_orders)).to eq connection.method(:request_open_orders)
    end
  end

  describe '#update_order_dependent_object (private)' do
    it 'yields the located order via local_id' do
      dependent = double('dependent')
      allow(dependent).to receive(:local_id).and_return(1)
      allow(dependent).to receive(:perm_id).and_return(nil)

      yielded = nil
      connection.send(:update_order_dependent_object, dependent) do |o|
        yielded = o
      end
      expect(yielded).to eq order
    end

    it 'falls back to perm_id when local_id is blank' do
      order.perm_id = 999
      dependent = double('dependent')
      allow(dependent).to receive(:local_id).and_return(nil)
      allow(dependent).to receive(:perm_id).and_return(999)

      yielded = nil
      connection.send(:update_order_dependent_object, dependent) do |o|
        yielded = o
      end
      expect(yielded).to eq order
    end

    it 'does not yield when the order is not found' do
      dependent = double('dependent')
      allow(dependent).to receive(:local_id).and_return(99_999)
      allow(dependent).to receive(:perm_id).and_return(nil)

      yielded = false
      connection.send(:update_order_dependent_object, dependent) do |_o|
        yielded = true
      end
      expect(yielded).to be false
    end
  end
end
