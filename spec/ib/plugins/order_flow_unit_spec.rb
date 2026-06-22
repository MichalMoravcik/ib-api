require 'spec_helper'
require File.expand_path('../../../../plugins/ib/order-flow', __FILE__)

describe IB::OrderFlow do
  let(:stub_socket) { IB::SocketStub.new }
  let(:connection) do
    c = IB::Connection.new
    c.socket = stub_socket
    c.instance_variable_set(:@connected, true)
    c
  end

  let(:order) do
    IB::Order.new(
      limit_price: 100,
      total_quantity: 100,
      action: :buy,
      order_type: 'LMT'
    )
  end

  let(:contract) do
    IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD')
  end

  before do
    IB::Connection.current = connection
    order.contract = contract
    allow(connection).to receive(:logger).and_return(double(info: nil, error: nil))
  end

  after do
    IB::Connection.current = nil
  end

  describe '#place' do
    context 'error cases' do
      it 'raises error when next_local_id is not known' do
        allow(connection).to receive(:next_local_id).and_return(nil)
        expect { order.place }.to raise_error(IB::Error, /next_local_id not known/)
      end

      it 'raises error when order is already placed (local_id present)' do
        allow(connection).to receive(:next_local_id).and_return(1)
        order.local_id = 123
        expect { order.place }.to raise_error(IB::Error, /local_id present/)
      end
    end

    context 'successful placement' do
      let(:queue) { Queue.new }

      before do
        allow(connection).to receive(:next_local_id).and_return(42)
        allow(connection).to receive(:next_local_id=)
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)
        allow(connection).to receive(:unsubscribe)

        # Setup queue to return with an order after a short delay
        Thread.new do
          sleep 0.01
          queue << IB::Order.new(local_id: 42, total_quantity: 100)
        end
        allow(Queue).to receive(:new).and_return(queue)
      end

      it 'sets local_id from next_local_id' do
        order.place
        expect(order.local_id).to eq(42)
      end

      it 'increments next_local_id' do
        expect(connection).to receive(:next_local_id=).with(43)
        order.place
      end

      it 'sets placed_at timestamp' do
        expect(order.placed_at).to be_nil
        order.place
        expect(order.placed_at).to be_a(Time)
      end
    end
  end

  describe '#modify' do
    let(:queue) { Queue.new }

    before do
      order.local_id = 1
    end

    context 'error cases' do
      it 'raises error when local_id is not specified' do
        order.local_id = nil
        expect { order.modify }.to raise_error(IB::Error, /local_id not specified/)
      end

      it 'raises error when contract is not an IB::Contract' do
        order.contract = 'not_a_contract'
        expect { order.modify }.to raise_error(IB::Error, /contract has to be specified/)
      end
    end

    context 'queue and subscription handling' do
      before do
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)
        allow(connection).to receive(:unsubscribe)
      end

      it 'subscribes to OpenOrder and Alert messages' do
        expect(connection).to receive(:subscribe).with(:OpenOrder, any_args).and_return(1)
        expect(connection).to receive(:subscribe).with(:Alert, any_args).and_return(1)

        Thread.new do
          sleep 0.01
          queue << IB::Order.new(local_id: 1, total_quantity: 100)
        end
        allow(Queue).to receive(:new).and_return(queue)

        order.modify
      end

      it 'sends PlaceOrder message with correct local_id' do
        order.local_id = 99
        expect(connection).to receive(:send_message).with(:PlaceOrder, hash_including(local_id: 99))

        Thread.new do
          sleep 0.01
          queue << IB::Order.new(local_id: 99, total_quantity: 100)
        end
        allow(Queue).to receive(:new).and_return(queue)

        order.modify
      end

      it 'sets modified_at timestamp' do
        Thread.new do
          sleep 0.01
          queue << IB::Order.new(local_id: 1, total_quantity: 100)
        end
        allow(Queue).to receive(:new).and_return(queue)

        expect(order.modified_at).to be_nil
        order.modify
        expect(order.modified_at).to be_a(Time)
      end

      it 'uses original contract when con_id is 0' do
        Thread.new do
          sleep 0.01
          queue << IB::Order.new(local_id: 1, total_quantity: 100)
        end
        allow(Queue).to receive(:new).and_return(queue)

        expect(connection).to receive(:send_message).with(:PlaceOrder, hash_including(
          contract: contract
        ))
        order.modify
      end
    end

    context 'order acceptance timeout' do
      before do
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)
        allow(connection).to receive(:logger).and_return(double(info: nil, error: nil))
      end

      it 'raises error when queue times out (order not accepted)' do
        # Simulate queue timeout: q.pop returns nil (queue closed by timeout thread),
        # then q.closed? returns true, triggering error handling
        closed_queue = double('queue')
        allow(closed_queue).to receive(:pop).and_return(nil)
        allow(closed_queue).to receive(:close)
        allow(closed_queue).to receive(:closed?).and_return(true)
        allow(Queue).to receive(:new).and_return(closed_queue)

        expect { order.modify }.to raise_error(IB::TransmissionError, /not accepted/)
      end
    end

    context 'successful order modification' do
      let(:returned_order) { IB::Order.new(local_id: 1, total_quantity: 100) }

      before do
        allow(connection).to receive(:subscribe).and_return(1)
        allow(connection).to receive(:send_message)
        allow(connection).to receive(:unsubscribe)

        Thread.new do
          sleep 0.01
          queue << returned_order
        end
        allow(Queue).to receive(:new).and_return(queue)
      end

      it 'returns the received order from queue' do
        result = order.modify
        expect(result).to eq(returned_order)
      end

      it 'unsubscribes from messages after receiving order' do
        expect(connection).to receive(:unsubscribe)
        order.modify
      end
    end
  end

  describe '#check_margin' do
    let(:order_state) do
      IB::OrderState.new(
        init_margin_after: 1000.to_d,
        equity_with_loan_after: 800.to_d,
        init_margin_change: 100.to_d
      )
    end

    before do
      order.order_state = order_state
      allow(connection).to receive(:logger).and_return(double(info: nil))
    end

    context 'error cases' do
      it 'raises error when order_state is nil' do
        order.order_state = nil
        expect { order.check_margin }.to raise_error(IB::Error, /forcast is not initialized/)
      end

      it 'raises error when init_margin_after is nil' do
        order_state.init_margin_after = nil
        expect { order.check_margin }.to raise_error(IB::Error, /forcast is not initialized/)
      end
    end

    context 'margin requirements met' do
      it 'returns self when utilization is below threshold (margin OK)' do
        # utilization = 200/800 = 0.25, 1 - 0.25 = 0.75 > 0.1
        order_state.init_margin_after = 200.to_d
        order_state.equity_with_loan_after = 800.to_d
        result = order.check_margin(0.1)
        expect(result).to eq(order)
      end

      it 'returns nil when utilization exceeds threshold (margin NOT met)' do
        # utilization = 1000/800 = 1.25, 1 - 1.25 = -0.25 < 0.1
        result = order.check_margin(0.1)
        expect(result).to be_nil
      end
    end

    context 'threshold boundary' do
      it 'returns nil when exactly at threshold' do
        # utilization = 0.9, 1 - 0.9 = 0.1, not greater than threshold
        order_state.init_margin_after = 900.to_d
        order_state.equity_with_loan_after = 1000.to_d
        result = order.check_margin(0.1)
        expect(result).to be_nil
      end

      it 'returns self when just above threshold' do
        # utilization = 0.89, 1 - 0.89 = 0.11 > 0.1
        order_state.init_margin_after = 890.to_d
        order_state.equity_with_loan_after = 1000.to_d
        result = order.check_margin(0.1)
        expect(result).to eq(order)
      end
    end
  end

  describe '#auto_adjust' do
    let(:contract_detail) { double('ContractDetail', min_tick: 0.01) }
    let(:contract_with_detail) do
      IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD').tap do |c|
        c.contract_detail = contract_detail
      end
    end

    before do
      # Stub verify to return an array with the contract
      allow(contract_with_detail).to receive(:verify).and_return([contract_with_detail])
    end

    context 'error cases' do
      it 'raises error when no contract is provided' do
        order.contract = nil
        expect { order.auto_adjust }.to raise_error(IB::Error, /No Contract provided/)
      end

      it 'raises error when contract is not IB::Contract' do
        order.contract = 'invalid'
        expect { order.auto_adjust }.to raise_error(IB::Error, /No Contract provided/)
      end
    end

    context 'price adjustment for non-Bag contracts' do
      before do
        order.contract = contract_with_detail
      end

      it 'does not modify limit_price if it is zero' do
        order.limit_price = 0
        original_price = order.limit_price
        order.auto_adjust
        expect(order.limit_price).to eq(original_price)
      end

      it 'adjusts limit_price to min_tick precision' do
        order.limit_price = 100.026
        order.auto_adjust
        expect(order.limit_price).to eq(100.03)
      end

      it 'does not modify aux_price if it is zero' do
        order.aux_price = 0
        original_price = order.aux_price
        order.auto_adjust
        expect(order.aux_price).to eq(original_price)
      end

      it 'adjusts aux_price to min_tick precision' do
        order.aux_price = 50.024
        order.auto_adjust
        expect(order.aux_price).to eq(50.02)
      end

      it 'adjusts both limit_price and aux_price when both are non-zero' do
        order.limit_price = 100.026
        order.aux_price = 50.024
        order.auto_adjust
        expect(order.limit_price).to eq(100.03)
        expect(order.aux_price).to eq(50.02)
      end
    end

    context 'different min_tick precision' do
      before do
        order.contract = contract_with_detail
      end

      it 'handles min_tick of 0.001 (2 decimal places)' do
        allow(contract_detail).to receive(:min_tick).and_return(0.001)
        order.limit_price = 100.126
        order.auto_adjust
        expect(order.limit_price.to_f).to eq(100.13)
      end

      it 'handles min_tick of 0.0001 (3 decimal places)' do
        allow(contract_detail).to receive(:min_tick).and_return(0.0001)
        order.limit_price = 100.1235
        order.auto_adjust
        expect(order.limit_price.to_f).to eq(100.124)
      end

      it 'handles min_tick of 1 (whole numbers)' do
        allow(contract_detail).to receive(:min_tick).and_return(1)
        order.limit_price = 100.6
        order.auto_adjust
        expect(order.limit_price).to eq(101)
      end

      it 'handles min_tick of 10' do
        allow(contract_detail).to receive(:min_tick).and_return(10)
        order.limit_price = 105.5
        order.auto_adjust
        expect(order.limit_price).to eq(110)
      end
    end

    context 'Bag contracts skip min_tick adjustment' do
      it 'does not adjust prices for Bag contracts' do
        bag_contract = IB::Bag.new
        order.contract = bag_contract
        order.limit_price = 100.026
        order.aux_price = 50.024
        # Should not raise error and should not modify prices
        order.auto_adjust
        expect(order.limit_price).to eq(100.026)
        expect(order.aux_price).to eq(50.024)
      end
    end
  end
end
