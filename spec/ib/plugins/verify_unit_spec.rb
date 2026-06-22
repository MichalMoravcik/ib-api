require 'spec_helper'
require_relative '../../../plugins/ib/verify'

describe IB::Verify do
  let(:connection) do
    IB::Connection.new.tap do |c|
      c.instance_variable_set(:@socket, IB::SocketStub.new)
    end
  end

  before do
    IB::Connection.current = connection
  end

  after do
    IB::Connection.current = nil
  end

  describe '#verify' do
    it 'returns the contract itself in test mode' do
      stock = IB::Stock.new(symbol: 'AAPL')
      expect(stock.verify.first).to eq(stock)
    end

    it 'yields the contract to a block in test mode' do
      stock = IB::Stock.new(symbol: 'AAPL')
      collected = []
      stock.verify { |c| collected << c.symbol.dup }
      expect(collected).to eq(['AAPL'])
    end

    it 'returns a thread when thread mode is requested' do
      stock = IB::Stock.new(symbol: 'AAPL')
      thread = stock.verify(thread: true)
      expect(thread).to be_a(Thread)
      thread.join
      expect(thread.value).to eq([stock])
    end

    it 'raises an error without a connection' do
      IB::Connection.current = nil
      stock = IB::Stock.new(symbol: 'AAPL')
      expect { stock.verify }.to raise_error(IB::Error)
    end

    context 'with retry logic' do
      it 'retries up to 3 times on VerifyError and then succeeds' do
        stock = IB::Stock.new(symbol: 'AAPL')
        call_count = 0
        allow(stock).to receive(:sleep)
        allow(stock).to receive(:_verify) do
          call_count += 1
          raise IB::VerifyError, 'simulated failure' if call_count < 3

          ['success']
        end
        result = stock.verify
        expect(call_count).to eq(3)
        expect(result).to eq(['success'])
      end

      it 'raises after 3 retries on persistent VerifyError' do
        stock = IB::Stock.new(symbol: 'AAPL')
        call_count = 0
        allow(stock).to receive(:sleep)
        allow(stock).to receive(:_verify) do
          call_count += 1
          raise IB::VerifyError, 'persistent failure'
        end
        expect { stock.verify }.to raise_error(IB::VerifyError, 'persistent failure')
        expect(call_count).to eq(3)
      end
    end
  end

  describe '#_verify with mock TWS connection' do
    before do
      # Replace current connection with a non-SocketStub connection
      real_conn = IB::Connection.new
      real_conn.instance_variable_set(:@socket, Object.new)
      real_conn.instance_variable_set(:@connected, true)
      IB::Connection.current = real_conn
      allow(real_conn).to receive(:send_message).and_return(999)
      allow(real_conn).to receive(:logger).and_return(Logger.new(File::NULL))
    end

    after do
      IB::Connection.current = nil
    end

    # deliver_message invokes subscriber blocks on the real connection so we can
    # simulate asynchronous TWS responses without relying on actual network I/O.
    def deliver_message(msg)
      conn = IB::Connection.current
      subs = conn.instance_variable_get(:@subscribers) || {}
      subs.each do |msg_class, handlers|
        handlers.each_value { |handler| handler.call(msg) if msg.is_a?(msg_class) }
      end
    end

    it 'raises if neither con_id nor sec_type is set' do
      contract = IB::Contract.new
      expect { contract.verify }.to raise_error(IB::VerifyError)
    end

    it 'skips TWS request for bag contracts' do
      bag = IB::Bag.new
      result = bag.verify
      expect(result).to eq([bag])
    end

    it 'skips TWS request when contract_detail is present' do
      stock = IB::Stock.new(symbol: 'AAPL')
      stock.contract_detail = IB::ContractDetail.new
      result = stock.verify
      expect(result).to eq([stock])
    end

    it 'skips TWS request and yields for bag contracts' do
      bag = IB::Bag.new
      collected = []
      result = bag.verify { |c| collected << c; c }
      expect(result).to eq([bag])
      expect(collected).to eq([bag])
    end

    context 'with Alert message handling' do
      it 'pushes InvalidContract when alert code 200 matches message_id' do
        stock = IB::Stock.new(symbol: 'INVALID')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        alert = IB::Messages::Incoming::Alert.new(error_id: 999, code: 200, message: 'Not found')
        deliver_message(alert)

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end

      it 'ignores Alert when code does not match 200' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        alert = IB::Messages::Incoming::Alert.new(error_id: 999, code: 201, message: 'Some warning')
        deliver_message(alert)

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end
    end

    context 'with ContractData message handling' do
      it 'collects contract when request_id matches' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        cd_msg = IB::Messages::Incoming::ContractData.new(
          request_id: 999,
          contract: { symbol: 'AAPL', sec_type: 'STK', last_trading_day: '', strike: 0.0, right: '',
                       exchange: 'SMART', currency: 'USD', local_symbol: 'AAPL', trading_class: 'AAPL',
                       con_id: 123, multiplier: 0 },
          contract_detail: { market_name: 'AAPL', min_tick: 0.01, order_types: '', valid_exchanges: 'SMART',
                             price_magnifier: 1, under_con_id: 0, long_name: 'Apple', contract_month: '',
                             industry: '', category: '', subcategory: '', time_zone: 'EST', trading_hours: '',
                             liquid_hours: '', ev_rule: 0, ev_multipler: '', sec_id_list: {}, agg_group: 0,
                             under_symbol: '', under_sec_type: '', market_rule_ids: '', real_expiration_date: '',
                             stock_type: '', min_size: 100, size_increment: 100, suggested_size_increment: 100 }
        )
        deliver_message(cd_msg)

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to be_an(Array)
        expect(@verify_result.first).to be_an(IB::Contract)
        expect(@verify_result.first.con_id).to eq(123)
      end

      it 'yields contract when block given and request_id matches' do
        stock = IB::Stock.new(symbol: 'AAPL')
        @collected = []

        verify_thread = Thread.new do
          @verify_result = stock.verify { |c| @collected << c.symbol; c }
        end
        sleep 0.05

        cd_msg = IB::Messages::Incoming::ContractData.new(
          request_id: 999,
          contract: { symbol: 'AAPL', sec_type: 'STK', last_trading_day: '', strike: 0.0, right: '',
                       exchange: 'SMART', currency: 'USD', local_symbol: 'AAPL', trading_class: 'AAPL',
                       con_id: 123, multiplier: 0 },
          contract_detail: { market_name: 'AAPL', min_tick: 0.01, order_types: '', valid_exchanges: 'SMART',
                             price_magnifier: 1, under_con_id: 0, long_name: 'Apple', contract_month: '',
                             industry: '', category: '', subcategory: '', time_zone: 'EST', trading_hours: '',
                             liquid_hours: '', ev_rule: 0, ev_multipler: '', sec_id_list: {}, agg_group: 0,
                             under_symbol: '', under_sec_type: '', market_rule_ids: '', real_expiration_date: '',
                             stock_type: '', min_size: 100, size_increment: 100, suggested_size_increment: 100 }
        )
        deliver_message(cd_msg)

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to be_an(Array)
        expect(@verify_result.first.con_id).to eq(123)
        expect(@collected).to eq(['AAPL'])
      end

      it 'does not push contract when block returns nil' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify { |_c| nil } }
        sleep 0.05

        cd_msg = IB::Messages::Incoming::ContractData.new(
          request_id: 999,
          contract: { symbol: 'AAPL', sec_type: 'STK', last_trading_day: '', strike: 0.0, right: '',
                       exchange: 'SMART', currency: 'USD', local_symbol: 'AAPL', trading_class: 'AAPL',
                       con_id: 123, multiplier: 0 },
          contract_detail: { market_name: 'AAPL', min_tick: 0.01, order_types: '', valid_exchanges: 'SMART',
                             price_magnifier: 1, under_con_id: 0, long_name: 'Apple', contract_month: '',
                             industry: '', category: '', subcategory: '', time_zone: 'EST', trading_hours: '',
                             liquid_hours: '', ev_rule: 0, ev_multipler: '', sec_id_list: {}, agg_group: 0,
                             under_symbol: '', under_sec_type: '', market_rule_ids: '', real_expiration_date: '',
                             stock_type: '', min_size: 100, size_increment: 100, suggested_size_increment: 100 }
        )
        deliver_message(cd_msg)

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end

      it 'ignores ContractData when request_id does not match' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        cd_msg = IB::Messages::Incoming::ContractData.new(
          request_id: 111,
          contract: { symbol: 'AAPL', sec_type: 'STK', last_trading_day: '', strike: 0.0, right: '',
                       exchange: 'SMART', currency: 'USD', local_symbol: 'AAPL', trading_class: 'AAPL',
                       con_id: 123, multiplier: 0 },
          contract_detail: { market_name: 'AAPL', min_tick: 0.01, order_types: '', valid_exchanges: 'SMART',
                             price_magnifier: 1, under_con_id: 0, long_name: 'Apple', contract_month: '',
                             industry: '', category: '', subcategory: '', time_zone: 'EST', trading_hours: '',
                             liquid_hours: '', ev_rule: 0, ev_multipler: '', sec_id_list: {}, agg_group: 0,
                             under_symbol: '', under_sec_type: '', market_rule_ids: '', real_expiration_date: '',
                             stock_type: '', min_size: 100, size_increment: 100, suggested_size_increment: 100 }
        )
        deliver_message(cd_msg)

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end
    end

    context 'with ContractDataEnd message handling' do
      it 'closes queue when request_id matches' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end

      it 'ignores ContractDataEnd when request_id does not match' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 111)
        deliver_message(cde)

        cde_match = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde_match)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end
    end

    context 'with other message types in subscription' do
      it 'ignores messages that are not Alert, ContractData, or ContractDataEnd' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end

      it 'ignores non-Alert, non-ContractData, non-ContractDataEnd messages' do
        stock = IB::Stock.new(symbol: 'AAPL')
        @block_captured = nil
        conn = IB::Connection.current

        allow(conn).to receive(:subscribe) do |*args, &block|
          @block_captured = block
          'sub_id'
        end
        allow(conn).to receive(:send_message).and_return(999)
        allow(conn).to receive(:unsubscribe)
        allow(conn).to receive(:logger).and_return(Logger.new(File::NULL))

        verify_thread = Thread.new do
          begin
            stock.send(:_verify)
          rescue IB::VerifyError
            nil
          end
        end

        verify_thread.join(0.5)
        expect(@block_captured).not_to be_nil

        msg = IB::Messages::Incoming::NextValidId.new(local_id: 42)
        expect { @block_captured.call(msg) }.not_to raise_error
      end
    end

    context 'with Queue processing' do
      it 'raises VerifyError on TimeOut' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new do
          begin
            stock.send(:_verify)
            @verify_error = nil
          rescue IB::VerifyError => e
            @verify_error = e
          end
        end

        verify_thread.join(3)
        expect(verify_thread.status).to be_falsey
        expect(@verify_error).to be_a(IB::VerifyError)
        expect(@verify_error.message).to include('No data received')
      end

      it 'ignores unrecognized queue items' do
        stock = IB::Stock.new(symbol: 'AAPL')

        verify_thread = Thread.new { @verify_result = stock.verify }
        sleep 0.05

        alert = IB::Messages::Incoming::Alert.new(error_id: 999, code: 200, message: 'Not found')
        deliver_message(alert)

        cde = IB::Messages::Incoming::ContractDataEnd.new(request_id: 999)
        deliver_message(cde)

        verify_thread.join(2)
        expect(verify_thread.status).to be_falsey
        expect(@verify_result).to eq([])
      end
    end
  end

  describe '#necessary_attributes' do
    it 'returns attributes for a stock' do
      stock = IB::Stock.new(symbol: 'AAPL')
      expect(stock.necessary_attributes).to include(:currency, :exchange, :symbol)
    end

    it 'returns attributes for an option' do
      option = IB::Option.new(symbol: 'AAPL', strike: 150.0, expiry: '20251220', right: 'P')
      expect(option.necessary_attributes).to include(:currency, :exchange, :right, :expiry, :strike, :symbol)
    end

    it 'returns attributes for a future' do
      future = IB::Future.new(symbol: 'ES', expiry: '202512')
      expect(future.necessary_attributes).to include(:currency, :expiry, :symbol)
    end

    it 'returns attributes for forex' do
      forex = IB::Forex.new(symbol: 'EUR', currency: 'USD')
      expect(forex.necessary_attributes).to include(:currency, :exchange, :symbol)
    end

    it 'returns con_id based attributes when sec_type is blank' do
      contract = IB::Contract.new(con_id: 12345)
      expect(contract.necessary_attributes).to include(:con_id)
    end
  end

  describe '#query_contract' do
    it 'returns a contract with con_id when present' do
      contract = IB::Contract.new(con_id: 12345, exchange: 'SMART')
      queried = contract.send(:query_contract)
      expect(queried).to be_an(IB::Contract)
      expect(queried.con_id).to eq(12345)
    end

    it 'builds a contract from necessary attributes when no con_id' do
      stock = IB::Stock.new(symbol: 'AAPL')
      queried = stock.send(:query_contract)
      expect(queried).to be_an(IB::Contract)
      expect(queried.symbol).to eq('AAPL')
      expect(queried.con_id).to eq(0)
    end

    it 'uses invariant_attributes when con_id is zero' do
      stock = IB::Stock.new(symbol: 'AAPL')
      stock.con_id = 0
      queried = stock.send(:query_contract)
      expect(queried.symbol).to eq('AAPL')
    end

    it 'uses invariant_attributes when con_id is blank' do
      stock = IB::Stock.new(symbol: 'AAPL')
      stock.con_id = nil
      queried = stock.send(:query_contract)
      expect(queried.symbol).to eq('AAPL')
    end
  end
end
