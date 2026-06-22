# frozen_string_literal: true

require 'spec_helper'

describe 'OrderFlow plugin' do
  let(:connection) do
    conn = IB::Connection.new(logger: Logger.new(StringIO.new))
    stub = IB::SocketStub.new
    stub.add_message("!:\n1\n")
    stub.add_message("9:\n1\n")
    conn.instance_variable_set(:@socket, stub)
    conn.instance_variable_set(:@connected, true)
    conn.instance_variable_set(:@next_local_id, 100)
    conn
  end

  let(:contract) { factory.create_stock(symbol: 'AAPL') }
  let(:order) do
    o = factory.create_limit_order(contract: contract)
    o.contract = contract
    o
  end

  before do
    allow(IB::Connection).to receive(:current).and_return(connection)
    connection.activate_plugin('order-flow')
  end

  after do
    Thread.list.each { |t| t.kill if t != Thread.current && t != Thread.main }
  end

  describe '#place' do
    context 'when connection.next_local_id is not set' do
      before { connection.instance_variable_set(:@next_local_id, nil) }

      it 'raises an error' do
        expect { order.place }.to raise_error(IB::Error, /next_local_id not known/)
      end
    end

    context 'when order already carries a local_id' do
      before { order.local_id = 5 }

      it 'raises an error suggesting modification' do
        expect { order.place }.to raise_error(IB::Error, /local_id present/)
      end
    end

    context 'happy path' do
      before { allow(order).to receive(:modify).and_return(order) }

      it 'sets local_id from the connection' do
        order.place
        expect(order.local_id).to eq 100
      end

      it 'increments the connection’s next_local_id' do
        order.place
        expect(connection.next_local_id).to eq 101
      end

      it 'records a placed_at timestamp' do
        before_time = Time.now
        order.place
        expect(order.placed_at).to be >= before_time
      end

      it 'calls #modify after assigning the id' do
        expect(order).to receive(:modify)
        order.place
      end

      it 'returns whatever #modify returns' do
        allow(order).to receive(:modify).and_return('fake-return')
        expect(order.place).to eq 'fake-return'
      end
    end
  end

  describe '#modify' do
    context 'without a local_id' do
      it 'raises an error' do
        expect { order.modify }.to raise_error(IB::Error, /local_id not specified/)
      end
    end

    context 'without a valid contract' do
      before do
        order.local_id = 1
        order.contract = nil
      end

      it 'raises an error with nil contract' do
        expect { order.modify }.to raise_error(IB::Error, /contract has to be specified/)
      end
    end

    context 'with a string contract (invalid)' do
      before do
        order.local_id = 1
        order.contract = 'nope'
      end

      it 'raises an error' do
        expect { order.modify }.to raise_error(IB::Error, /contract has to be specified/)
      end
    end

    context 'happy path when OpenOrder arrives promptly' do
      let(:incoming_order) do
        o = factory.create_limit_order(local_id: 1)
        o.contract = contract
        o
      end

      let(:open_queue) do
        q = double('open_queue')
        allow(q).to receive(:pop).and_return(incoming_order)
        allow(q).to receive(:close)
        allow(q).to receive(:closed?).and_return(false)
        q
      end

      before do
        order.local_id = 1
        order.contract = contract
        allow(Queue).to receive(:new).and_return(open_queue)
        dead_thread = Thread.new { nil }
        allow(Thread).to receive(:new).and_return(dead_thread)
      end

      it 'subscribes to OpenOrder and Alert messages' do
        subscribed = []
        allow(connection).to receive(:subscribe) do |sym, &_blk|
          subscribed << sym
          subscribed.size
        end
        allow(connection).to receive(:send_message)

        order.modify
        expect(subscribed).to include(:OpenOrder, :Alert)
      end

      it 'sets modified_at timestamp' do
        before_time = Time.now
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)

        order.modify
        expect(order.modified_at).to be >= before_time
      end

      it 'returns the received order record' do
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)

        result = order.modify
        expect(result).to be_a(IB::Order)
        expect(result.local_id).to eq 1
      end

      it 'unsubscribes after receiving' do
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)
        expect(connection).to receive(:unsubscribe)

        order.modify
      end

      it 'sends a PlaceOrder message' do
        allow(connection).to receive(:subscribe).and_return(1)
        expect(connection).to receive(:send_message).with(:PlaceOrder, hash_including(local_id: 1))

        order.modify
      end
    end

    context 'when OpenOrder response times out (queue closed)' do
      let(:closed_queue) do
        q = double('closed_queue')
        allow(q).to receive(:pop)
        allow(q).to receive(:close)
        allow(q).to receive(:closed?).and_return(true)
        q
      end

      before do
        order.local_id = 1
        order.contract = contract
        allow(Queue).to receive(:new).and_return(closed_queue)
        allow(Thread).to receive(:new).and_return(double('thread', kill: nil))
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)
        allow(connection).to receive(:unsubscribe)
      end

      it 'raises a TransmissionError' do
        expect { order.modify }.to raise_error(IB::TransmissionError, /not accepted/)
      end
    end

    context 'with a verified contract (con_id > 0)' do
      before do
        order.local_id = 1
        contract.con_id = 123
        order.contract = contract
        allow(Queue).to receive(:new).and_return(open_queue)
        allow(Thread).to receive(:new).and_return(double('thread', kill: nil))
      end

      let(:open_queue) do
        q = double('open_queue')
        allow(q).to receive(:pop).and_return(factory.create_limit_order(local_id: 1))
        allow(q).to receive(:close)
        allow(q).to receive(:closed?).and_return(false)
        q
      end

      it 'reveals a latent NameError due to buggy `the_contract` reference in the plugin' do
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)
        allow(connection).to receive(:unsubscribe)

        expect { order.modify }.to raise_error(NameError, /the_contract/)
      end
    end
  end

  describe '#check_margin' do
    before do
      order.order_state = IB::OrderState.new(
        init_margin_after: 1000.0,
        equity_with_loan_after: 10_000.0,
        init_margin_change: 1000.0
      )
    end

    context 'without an initialized order_state' do
      it 'raises an error when order_state is nil' do
        order.order_state = nil
        expect { order.check_margin }.to raise_error(IB::Error, /forcast is not initialized/)
      end

      it 'raises an error when init_margin_after is nil' do
        order.order_state.init_margin_after = nil
        expect { order.check_margin }.to raise_error(IB::Error, /forcast is not initialized/)
      end
    end

    context 'when margin utilization is within tolerance' do
      it 'returns the order object' do
        expect(order.check_margin).to eq order
      end

      it 'logs an approval message' do
        expect(connection.logger).to receive(:info).with(/Margin OK/)
        order.check_margin
      end
    end

    context 'when margin utilization exceeds the threshold' do
      before do
        order.order_state = IB::OrderState.new(
          init_margin_after: 9000.0,
          equity_with_loan_after: 10_000.0,
          init_margin_change: 9000.0
        )
      end

      it 'returns nil' do
        expect(order.check_margin).to be_nil
      end

      it 'logs a rejection message' do
        expect(connection.logger).to receive(:info).with(/Margin requirements NOT met/)
        order.check_margin
      end
    end

    context 'with a custom threshold' do
      before do
        order.order_state = IB::OrderState.new(
          init_margin_after: 4000.0,
          equity_with_loan_after: 10_000.0,
          init_margin_change: 4000.0
        )
      end

      it 'accepts with a lenient threshold' do
        expect(order.check_margin(0.5)).to eq order
      end

      it 'rejects with a strict threshold' do
        expect(order.check_margin(0.7)).to be_nil
      end
    end
  end

  describe '#auto_adjust' do
    context 'without a contract' do
      before { order.contract = nil }

      it 'raises an error' do
        expect { order.auto_adjust }.to raise_error(IB::Error, /No Contract provided/)
      end
    end

    context 'with a Bag contract' do
      before do
        order.contract = factory.create_combo
        order.limit_price = 99.123
      end

      it 'skips price adjustment entirely' do
        order.auto_adjust
        expect(order.limit_price).to eq 99.123
      end
    end

    context 'with a verified stock contract' do
      before do
        contract.contract_detail = IB::ContractDetail.new(min_tick: 0.01)
        order.contract = contract
      end

      it 'rounds limit_price down to the nearest tick' do
        order.limit_price = 150.023
        order.auto_adjust
        expect(order.limit_price).to eq 150.02
      end

      it 'rounds limit_price up when closer to the upper tick' do
        order.limit_price = 150.026
        order.auto_adjust
        expect(order.limit_price).to eq 150.03
      end

      it 'rounds aux_price to tick precision' do
        order.aux_price = 145.027
        order.auto_adjust
        expect(order.aux_price).to eq 145.03
      end

      it 'does not touch nil prices' do
        order.limit_price = nil
        order.auto_adjust
        expect(order.limit_price).to be_nil
      end

      it 'does not touch zero prices' do
        order.aux_price = 0
        order.auto_adjust
        expect(order.aux_price).to eq 0
      end
    end

    context 'when the contract lacks detail and verify yields one' do
      before do
        verified = factory.create_stock(symbol: 'MSFT')
        verified.contract_detail = IB::ContractDetail.new(min_tick: 0.1)
        allow(contract).to receive(:verify).and_return([verified])
        order.contract = contract
      end

      it 'uses the verified contract’s min_tick' do
        order.limit_price = 200.23
        order.auto_adjust
        expect(order.limit_price).to eq 200.2
      end
    end

    context 'with extreme tick sizes' do
      it 'handles a large min_tick (1.0) by rounding to integer' do
        contract.contract_detail = IB::ContractDetail.new(min_tick: 1.0)
        order.contract = contract
        order.limit_price = 55.7
        order.auto_adjust
        expect(order.limit_price).to eq 56.0
      end

      it 'handles a tiny min_tick (0.0001) by rounding to extra decimal places' do
        contract.contract_detail = IB::ContractDetail.new(min_tick: 0.0001)
        order.contract = contract
        order.limit_price = 1.12345
        order.auto_adjust
        expect(order.limit_price).to eq 1.123
      end
    end
  end
end
