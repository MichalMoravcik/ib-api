# frozen_string_literal: true

require 'spec_helper'

describe 'ProcessOrders plugin unit coverage' do
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

  describe 'OpenOrder handler with Bag contract' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::OpenOrder].values.first
    end

    let(:bag_contract) do
      bag = IB::Bag.new(symbol: 'USD', exchange: 'SMART', currency: 'USD')
      leg1 = IB::ComboLeg.new(con_id: 123, ratio: 1, action: 'BUY', exchange: 'SMART')
      leg2 = IB::ComboLeg.new(con_id: 456, ratio: 1, action: 'SELL', exchange: 'SMART')
      bag.combo_legs = [leg1, leg2]
      bag
    end

    let(:bag_order) do
      o = factory.create_limit_order(local_id: 2, total_quantity: 10)
      o.contract = bag_contract
      o.account = 'DU123456'
      o
    end

    let(:open_order_msg) do
      msg = IB::Messages::Incoming::OpenOrder.new(
        order_id: 2,
        contract: bag_contract.attributes.merge(sec_type: 'BAG'),
        order: bag_order.attributes.merge(local_id: 2, perm_id: 998, client_id: 1, parent_id: 0),
        order_state: { status: 'Submitted' }
      )
      msg.instance_variable_set(:@contract, bag_contract)
      msg
    end

    it 'sets negative con_id for Bag contracts based on combo_legs sum' do
      subscriber.call(open_order_msg)
      expect(open_order_msg.contract.con_id).to eq(-579)
    end

    it 'saves the bag order to the account by local_id' do
      account.orders = []
      subscriber.call(open_order_msg)
      expect(account.orders.map(&:local_id)).to include(2)
    end

    it 'saves the bag contract to account contracts' do
      subscriber.call(open_order_msg)
      bag_in_account = account.contracts.find { |c| c.is_a?(IB::Bag) }
      expect(bag_in_account).to be_present
    end
  end

  describe 'ExecutionData handler with sell action' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::ExecutionData].values.first
    end

    let(:sell_order) do
      o = factory.create_limit_order(local_id: 1, action: 'SELL')
      o.contract = contract
      o.account = 'DU123456'
      o.total_quantity = 100
      o.action = :sell
      o.order_state = IB::OrderState.new(status: 'Submitted')
      o
    end

    before do
      account.orders = [sell_order]
    end

    let(:execution_msg) do
      IB::Messages::Incoming::ExecutionData.new(
        order_id: 1,
        contract: contract.attributes.merge(sec_type: 'STK'),
        execution: {
          exec_id: 'EXEC002',
          local_id: 1,
          shares: 100,
          cumulative_quantity: 100,
          price: 150.0,
          average_price: 150.0,
          side: 'SLD',
          account_name: 'DU123456'
        }
      )
    end

    it 'stores execution on the matched sell order' do
      expect { subscriber.call(execution_msg) }.to change { sell_order.executions.size }.by(1)
    end

    it 'creates a negative portfolio value for sell execution' do
      sell_order.total_quantity = 100
      sell_order.action = :sell
      subscriber.call(execution_msg)
      pv = account.portfolio_values.find { |p| p.contract.con_id == contract.con_id }
      expect(pv).to be_present
      expect(pv.position).to eq(-100)
    end

    it 'updates existing portfolio value with negative change for sell' do
      sell_order.total_quantity = 100
      sell_order.action = :sell
      account.portfolio_values << IB::PortfolioValue.new(position: 50, contract: contract)
      subscriber.call(execution_msg)
      pv = account.portfolio_values.find { |p| p.contract.con_id == contract.con_id }
      expect(pv.position).to eq(-50)
    end

    it 'logs execution completion for sell orders' do
      log_output = StringIO.new
      test_logger = Logger.new(log_output)
      allow(connection).to receive(:logger).and_return(test_logger)
      sell_order.total_quantity = 100
      sell_order.action = :sell
      subscriber.call(execution_msg)
      expect(log_output.string).to match(/Execution completed/)
    end
  end

  describe 'ExecutionData handler partial fill logging' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::ExecutionData].values.first
    end

    let(:partial_execution_msg) do
      IB::Messages::Incoming::ExecutionData.new(
        order_id: 1,
        contract: contract.attributes.merge(sec_type: 'STK'),
        execution: {
          exec_id: 'EXEC003',
          local_id: 1,
          shares: 50,
          cumulative_quantity: 50,
          price: 150.0,
          average_price: 150.0,
          side: 'BOT',
          account_name: 'DU123456'
        }
      )
    end

    it 'logs debug message when execution is not completed' do
      log_output = StringIO.new
      test_logger = Logger.new(log_output)
      allow(connection).to receive(:logger).and_return(test_logger)
      order.total_quantity = 100
      order.action = :buy
      subscriber.call(partial_execution_msg)
      expect(log_output.string).to match(/Execution not completed/)
    end

    it 'does not create portfolio value on partial execution' do
      order.total_quantity = 100
      order.action = :buy
      subscriber.call(partial_execution_msg)
      expect(account.portfolio_values).to be_empty
    end
  end

  describe 'OrderStatus handler edge cases' do
    let(:subscriber) do
      subscribers[IB::Messages::Incoming::OrderStatus].values.first
    end

    it 'locates order by perm_id when local_id is blank' do
      order.perm_id = 777
      order.local_id = 1

      order_status_msg = IB::Messages::Incoming::OrderStatus.new(
        order_state: {
          local_id: nil,
          status: 'Filled',
          filled: 100,
          remaining: 0,
          average_fill_price: 150.0,
          perm_id: 777,
          parent_id: 0,
          last_fill_price: 150.0,
          client_id: 1,
          why_held: '',
          market_cap_price: 0
        }
      )

      expect { subscriber.call(order_status_msg) }.to change { order.order_states.size }.by(1)
    end

    it 'inserts order state with save_insert avoiding duplicates by status' do
      order.order_states << IB::OrderState.new(status: 'Filled', local_id: 1)

      order_status_msg = IB::Messages::Incoming::OrderStatus.new(
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

      # save_insert with overwrite=true replaces existing item with same status
      subscriber.call(order_status_msg)
      filled_states = order.order_states.select { |os| os.status == 'Filled' }
      expect(filled_states.size).to eq(1)
    end
  end

  describe '#request_open_orders success path' do
    it 'kills timeout thread and closes queue on success' do
      open_queue = Queue.new
      allow(open_queue).to receive(:pop).and_return(true)
      allow(open_queue).to receive(:close)
      allow(open_queue).to receive(:closed?).and_return(false)

      allow(Queue).to receive(:new).and_return(open_queue)
      allow(Thread).to receive(:new).and_return(Thread.new { nil })
      allow(connection).to receive(:send_message)
      allow(connection).to receive(:subscribe).with(:OpenOrderEnd).and_return(99)
      allow(connection).to receive(:unsubscribe)
      allow(Thread).to receive(:kill)

      connection.request_open_orders

      expect(Thread).to have_received(:kill)
      expect(open_queue).to have_received(:close)
    end
  end

  describe 'NextValidId subscriber registration' do
    it 'registers NextValidId subscriber even though no-op in case' do
      subs = subscribers
      expect(subs.keys).to include(IB::Messages::Incoming::NextValidId)
    end

    it 'handles NextValidId message without error (else branch)' do
      subscriber = subscribers[IB::Messages::Incoming::NextValidId].values.first
      msg = IB::Messages::Incoming::NextValidId.new(order_id: 1, local_id: 42)
      expect { subscriber.call(msg) }.not_to raise_error
    end
  end
end
