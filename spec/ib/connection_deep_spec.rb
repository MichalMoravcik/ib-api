require 'spec_helper'

RSpec.describe IB::Connection, 'deep unit coverage' do
  let(:ib) { IB::Connection.new }
  let(:stub_socket) { IB::SocketStub.new }

  def add_raw_message(socket, *fields)
    payload = fields.map(&:to_s).join("\0") + "\0"
    socket.add_message([payload.bytesize].pack('N') + payload)
  end

  before do
    allow(IB::Socket).to receive(:open).and_return(stub_socket)
    ib.try_connection!
    ib.instance_variable_set(:@connected, true)
    ib.instance_variable_set(:@received, true)
  end

  describe '#wait_for' do
    it 'returns when a message type is received' do
      ib.received[:NextValidId] << :dummy
      expect { ib.wait_for(:NextValidId) }.not_to raise_error
    end

    it 'returns when a custom condition is satisfied' do
      satisfied = false
      expect { ib.wait_for(0.1) { satisfied = true } }.not_to raise_error
    end
  end

  describe '#update_next_order_id' do
    it 'requests and stores next order id' do
      add_raw_message(stub_socket, 9, 1, 5)
      expect(ib.update_next_order_id).to eq(5)
      expect(ib.next_local_id).to eq(5)
    end
  end

  describe '#process_message' do
    it 'delivers a message to subscribers' do
      received = nil
      ib.subscribe(:NextValidId) { |msg| received = msg }
      add_raw_message(stub_socket, 9, 1, 5)
      ib.send(:process_message)
      expect(received).to be_a(IB::Messages::Incoming::NextValidId)
    end

    it 'stores message in received hash' do
      add_raw_message(stub_socket, 9, 1, 5)
      ib.send(:process_message)
      expect(ib.received?(:NextValidId)).to be true
    end
  end

  describe '#reconnect' do
    it 'returns early from nil workflow state' do
      ib2 = IB::Connection.new
      ib2.instance_variable_set(:@workflow_state, 'virgin')
      expect(ib2.reconnect).to be_nil
    end
  end

  describe '#subscribe' do
    let(:fresh_ib) { IB::Connection.new }

    it 'accepts a Proc as last argument' do
      proc = ->(msg) { }
      id = fresh_ib.subscribe(:NextValidId, proc)
      expect(id).to be_a(Integer)
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).to have_key(id)
    end

    it 'accepts a block' do
      id = fresh_ib.subscribe(:NextValidId) { |msg| }
      expect(id).to be_a(Integer)
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).to have_key(id)
    end

    it 'raises error when neither Proc nor block given' do
      expect { fresh_ib.subscribe(:NextValidId) }.to raise_error(/Need subscriber proc or block/)
    end

    it 'raises error for invalid Symbol message type' do
      expect { fresh_ib.subscribe(:InvalidMessageType) { |msg| } }.to raise_error(/InvalidMessageType is no IB::Messages class/)
    end

    it 'accepts Regexp to match message classes' do
      id = fresh_ib.subscribe(/NextValid/) { |msg| }
      expect(id).to be_a(Integer)
      # Should subscribe to NextValidId class
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).to have_key(id)
    end

    it 'accepts Class argument' do
      id = fresh_ib.subscribe(IB::Messages::Incoming::NextValidId) { |msg| }
      expect(id).to be_a(Integer)
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).to have_key(id)
    end

    it 'raises error for invalid argument type' do
      expect { fresh_ib.subscribe(123) { |msg| } }.to raise_error(/must represent incoming IB message class/)
    end
  end

  describe '#unsubscribe' do
    let(:fresh_ib) { IB::Connection.new }
    
    before do
      @subscriber_id = fresh_ib.subscribe(:NextValidId) { |msg| }
    end

    it 'removes subscriber' do
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).to have_key(@subscriber_id)
      fresh_ib.unsubscribe(@subscriber_id)
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).to be_empty
    end

    it 'logs error when unsubscribing non-existent id' do
      allow(fresh_ib.logger).to receive(:error)
      fresh_ib.unsubscribe(999999)
      expect(fresh_ib.logger).to have_received(:error).with(/No subscribers with id 999999/)
    end
  end

  describe '#update_next_order_id' do
    it 'calls try_connection when not connected' do
      ib2 = IB::Connection.new
      allow(ib2).to receive(:connected?).and_return(false)
      expect(ib2).to receive(:try_connection!)
      allow(ib2).to receive(:send_message)
      allow(ib2).to receive(:subscribe).and_return(1)
      allow(ib2).to receive(:unsubscribe)
      q = Queue.new
      q.push(42)
      allow(Queue).to receive(:new).and_return(q)
      ib2.update_next_order_id
    end

    it 'requests new id even when already connected' do
      ib.instance_variable_set(:@connected, true)
      add_raw_message(stub_socket, 9, 1, 100)
      expect(ib.update_next_order_id).to eq(100)
      expect(ib.next_local_id).to eq(100)
    end

    it 'handles timeout when queue closes' do
      allow(ib).to receive(:send_message).with(:RequestIds)
      # Simulate no response from TWS (queue closes after 5 seconds)
      expect { ib.update_next_order_id }.to raise_error(/Could not get NextValidID/)
    end
  end

  describe '#try_connection' do
    it 'returns early if already connected' do
      ib.instance_variable_set(:@connected, true)
      expect { ib.send(:try_connection) }.to raise_error(/Already connected/)
    end
  end

  describe '#process_messages error handling' do
    it 'raises IB::TransmissionError on ECONNRESET' do
      allow(ib).to receive(:socket).and_raise(Errno::ECONNRESET.new('Connection reset by peer'))
      allow(ib.logger).to receive(:fatal)
      expect { ib.send(:process_messages, 1) }.to raise_error(IB::TransmissionError, /try reconnecting/)
      expect(ib.logger).to have_received(:fatal).with(/Connection reset by peer/).at_least(:once)
    end
  end

  describe '#clear_received' do
    it 'clears all message types when no arguments given' do
      ib.received[:NextValidId] << :dummy1
      ib.received[:OrderStatus] << :dummy2
      ib.clear_received
      expect(ib.received[:NextValidId]).to be_empty
      expect(ib.received[:OrderStatus]).to be_empty
    end

    it 'clears only specified message types' do
      ib.received[:NextValidId] << :dummy1
      ib.received[:OrderStatus] << :dummy2
      ib.clear_received(:NextValidId)
      expect(ib.received[:NextValidId]).to be_empty
      expect(ib.received[:OrderStatus]).not_to be_empty
    end
  end

  describe '#received?' do
    it 'returns true when message received at least n times' do
      ib.received[:NextValidId] << :dummy1
      ib.received[:NextValidId] << :dummy2
      expect(ib.received?(:NextValidId, 2)).to be true
    end

    it 'returns false when message received fewer than n times' do
      ib.received[:NextValidId] << :dummy1
      expect(ib.received?(:NextValidId, 2)).to be false
    end

    it 'returns true by default when times is 1' do
      ib.received[:NextValidId] << :dummy1
      expect(ib.received?(:NextValidId)).to be true
    end
  end

  describe '#send_message' do
    let(:fresh_ib) { IB::Connection.new }

    it 'raises error when not connected' do
      allow(fresh_ib).to receive(:connected?).and_return(false)
      expect { fresh_ib.send_message(:RequestIds) }.to raise_error(/Not able to send messages/)
    end

    it 'raises error for invalid message type' do
      allow(fresh_ib).to receive(:connected?).and_return(true)
      expect { fresh_ib.send_message('NotAMessageType') }.to raise_error(/Only able to send outgoing IB messages/)
    end
  end

  describe '#place_order' do
    it 'raises error when next_local_id not known' do
      ib.instance_variable_set(:@next_local_id, nil)
      order = IB::Order.new
      contract = IB::Stock.new(symbol: 'AAPL')
      expect { ib.place_order(order, contract) }.to raise_error(/next_local_id not known/)
    end

    it 'raises error when order already placed' do
      ib.instance_variable_set(:@next_local_id, 1)
      order = IB::Order.new(local_id: 5)
      contract = IB::Stock.new(symbol: 'AAPL')
      expect { ib.place_order(order, contract) }.to raise_error(/local_id present.*already placed/)
    end
  end

  describe '#modify_order' do
    it 'raises error when local_id is nil' do
      order = IB::Order.new
      contract = IB::Stock.new(symbol: 'AAPL')
      expect { ib.modify_order(order, contract) }.to raise_error(/local_id not specified/)
    end
  end

  describe '#cancel_order' do
    it 'sends CancelOrder for each local_id' do
      expect(ib).to receive(:send_message).with(:CancelOrder, { local_id: 1 })
      expect(ib).to receive(:send_message).with(:CancelOrder, { local_id: 2 })
      ib.cancel_order(1, 2)
    end
  end

  describe '#start_reader' do
    it 'returns existing reader thread if already running' do
      thread = Thread.new { }
      ib.instance_variable_set(:@reader_running, true)
      ib.instance_variable_set(:@reader_thread, thread)
      result = ib.send(:start_reader)
      expect(result).to eq(thread)
      thread.kill
    end
  end

  describe '#satisfied?' do
    it 'returns false when no conditions given' do
      expect(ib.send(:satisfied?)).to be false
    end

    it 'handles Symbol condition' do
      allow(ib).to receive(:received?).with(:NextValidId).and_return(true)
      expect(ib.send(:satisfied?, :NextValidId)).to be true
    end

    it 'handles Array condition [symbol, times]' do
      allow(ib).to receive(:received?).with(:NextValidId, 2).and_return(true)
      expect(ib.send(:satisfied?, [:NextValidId, 2])).to be true
    end

    it 'handles callable condition' do
      condition = -> { true }
      expect(ib.send(:satisfied?, condition)).to be true
    end

    it 'logs error for unknown condition type' do
      allow(ib.logger).to receive(:error)
      expect(ib.send(:satisfied?, 'invalid')).to be_nil
      expect(ib.logger).to have_received(:error)
    end
  end

  describe '#wait_for' do
    it 'times out when condition never met' do
      # This should return after ~0.1 seconds (timeout), not hang
      expect { ib.wait_for(0.1) { false } }.not_to raise_error
    end

    it 'uses process_messages when reader not running' do
      ib.instance_variable_set(:@reader_running, false)
      allow(ib).to receive(:process_messages)
      ib.wait_for(0.02) { false }
      expect(ib).to have_received(:process_messages).at_least(:once)
    end
  end

  describe '#reconnect' do
    it 'logs workflow transition when reconnecting' do
      allow(ib.logger).to receive(:warn)
      allow(ib).to receive(:disconnect!)
      allow(ib).to receive(:unsubscribe)
      allow(ib).to receive(:try_connection!)
      allow(ib).to receive(:activate_managed_accounts!)
      allow(ib).to receive(:initialize_managed_accounts!)
      allow(ib).to receive(:initialize_order_handling!)
      ib.instance_variable_set(:@workflow_state, 'lean_mode')
      ib.reconnect
    end
  end

  describe '#process_message edge cases' do
    it 'logs fatal when message type not found' do
      allow(ib.logger).to receive(:fatal)
      add_raw_message(stub_socket, 9999, 1, 'data')
      expect { ib.send(:process_message) }.to raise_error(/unsupported message/)
      expect(ib.logger).to have_received(:fatal).at_least(:once)
    end
  end

  describe '#reconnect workflow branches' do
    it 'calls initialize_order_handling when reconnecting from account_based_orderflow' do
      allow(ib.logger).to receive(:warn)
      allow(ib).to receive(:disconnect!)
      allow(ib).to receive(:unsubscribe)
      allow(ib).to receive(:try_connection!)
      allow(ib).to receive(:activate_managed_accounts!)
      allow(ib).to receive(:initialize_managed_accounts!)
      expect(ib).to receive(:initialize_order_handling!)
      ib.instance_variable_set(:@workflow_state, 'account_based_orderflow')
      ib.reconnect
    end
  end

  describe '#initialize' do
    it 'sets Connection.current to self' do
      connection = IB::Connection.new
      expect(IB::Connection.current).to eq(connection)
    end

    it 'accepts host:port combination string' do
      connection = IB::Connection.new(host: 'localhost:4001')
      expect(connection.host).to eq('localhost')
      expect(connection.port).to eq('4001')
    end

    it 'accepts separate host and port parameters' do
      connection = IB::Connection.new(host: 'localhost', port: '4001')
      expect(connection.host).to eq('localhost')
      expect(connection.port).to eq('4001')
    end

    it 'uses default host:port when not specified' do
      connection = IB::Connection.new
      expect(connection.host).to eq('127.0.0.1')
      expect(connection.port).to eq('4002')
    end

    it 'accepts logger parameter' do
      logger = Logger.new(StringIO.new)
      connection = IB::Connection.new(logger: logger)
      expect(connection.logger).to eq(logger)
    end

    it 'generates random client_id in range' do
      connection = IB::Connection.new
      expect(connection.client_id).to be >= 1001
      expect(connection.client_id).to be <= 9999
    end

    it 'accepts custom client_id' do
      connection = IB::Connection.new(client_id: 1234)
      expect(connection.client_id).to eq(1234)
    end

    it 'accepts plugins array' do
      connection = IB::Connection.new(plugins: ['verify'])
      expect(connection.plugins).to eq(['verify'])
    end

    it 'yields self when block given' do
      yielded = nil
      connection = IB::Connection.new do |c|
        yielded = c
      end
      expect(yielded).to eq(connection)
    end

    it 'initializes with nil next_local_id' do
      connection = IB::Connection.new
      expect(connection.next_local_id).to be_nil
    end

    it 'initializes instance variables from keyword arguments' do
      connection = IB::Connection.new(client_version: '123', optional_capacities: '+PACEAPI')
      expect(connection.client_version).to eq('123')
      expect(connection.instance_variable_get(:@optional_capacities)).to eq('+PACEAPI')
    end

    it 'ignores extra keyword arguments' do
      expect {
        IB::Connection.new(some_extra: 'value', another_extra: 123)
      }.not_to raise_error
    end

    it 'initializes mutex locks' do
      connection = IB::Connection.new
      expect(connection.instance_variable_get(:@subscribe_lock)).to be_a(Mutex)
      expect(connection.instance_variable_get(:@receive_lock)).to be_a(Mutex)
      expect(connection.instance_variable_get(:@message_lock)).to be_a(Mutex)
    end

    it 'initializes @connected as false' do
      connection = IB::Connection.new
      expect(connection.instance_variable_get(:@connected)).to be false
    end

    it 'initializes @parser as nil' do
      connection = IB::Connection.new
      expect(connection.instance_variable_get(:@parser)).to be_nil
    end
  end

  describe '#try_connection error handling' do
    it 'raises Errno::ECONNREFUSED when socket.open fails' do
      allow(IB::Socket).to receive(:open).and_raise(Errno::ECONNREFUSED)
      connection = IB::Connection.new
      expect { connection.send(:try_connection) }.to raise_error(Errno::ECONNREFUSED)
    end

    it 'logs fatal and retries on TransmissionError' do
      error = IB::TransmissionError.new('test')
      allow(error).to receive(:msg).and_return('test')
      allow(IB::Socket).to receive(:open).and_raise(error)
      logger = double('logger', fatal: nil, progname: 'IB::Connection#Event:TryConnection')
      allow(logger).to receive(:progname=)
      allow(IB::Connection).to receive(:configure_logger)
      connection = IB::Connection.new
      allow(connection).to receive(:logger).and_return(logger)
      allow(connection).to receive(:subscribe)
      allow(connection).to receive(:disconnect!)
      allow(connection).to receive(:try_connection!).and_raise(IB::TransmissionError.new('retry'))
      expect { connection.send(:try_connection) }.to raise_error(IB::TransmissionError)
      expect(logger).to have_received(:fatal).with(/Transmission Error/)
      expect(logger).to have_received(:fatal).with('test')
    end
  end

  describe '#subscribe error cases' do
    let(:fresh_ib) { IB::Connection.new }

    it 'raises error when no subscriber (Proc or block) provided' do
      expect { fresh_ib.subscribe(:NextValidId) }.to raise_error(/Need subscriber proc or block/)
    end

    it 'raises error for invalid message type symbol' do
      expect { fresh_ib.subscribe(:InvalidMessageType) { |msg| } }.to raise_error(/InvalidMessageType is no IB::Messages class/)
    end

    it 'raises error for non-Class, non-Symbol, non-Regexp argument' do
      expect { fresh_ib.subscribe(123) { |msg| } }.to raise_error(/must represent incoming IB message class/)
    end
  end

  describe '#unsubscribe' do
    let(:fresh_ib) { IB::Connection.new }
    
    before do
      @subscriber_id = fresh_ib.subscribe(:NextValidId) { |msg| }
      @subscriber_id2 = fresh_ib.subscribe(:CurrentTime) { |msg| }
    end

    it 'removes subscriber from all message classes' do
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).to have_key(@subscriber_id)
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::CurrentTime]).to have_key(@subscriber_id2)
      
      fresh_ib.unsubscribe(@subscriber_id, @subscriber_id2)
      
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::NextValidId]).not_to have_key(@subscriber_id)
      expect(fresh_ib.send(:subscribers)[IB::Messages::Incoming::CurrentTime]).not_to have_key(@subscriber_id2)
    end

    it 'returns array of removed subscribers' do
      result = fresh_ib.unsubscribe(@subscriber_id)
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end

    it 'logs error when unsubscribing non-existent id' do
      allow(fresh_ib.logger).to receive(:error)
      fresh_ib.unsubscribe(999999)
      expect(fresh_ib.logger).to have_received(:error).with(/No subscribers with id 999999/)
    end
  end

  describe '#send_message' do
    let(:fresh_ib) { IB::Connection.new }

    it 'accepts message Class argument' do
      allow(fresh_ib).to receive(:connected?).and_return(true)
      allow(fresh_ib).to receive(:socket).and_return(double('socket'))
      expect(IB::Messages::Outgoing::RequestIds).to receive(:new).and_return(double('message', send_to: nil, data: {}))
      fresh_ib.send_message(IB::Messages::Outgoing::RequestIds)
    end

    it 'returns request_id when present' do
      allow(fresh_ib).to receive(:connected?).and_return(true)
      allow(fresh_ib).to receive(:socket).and_return(double('socket'))
      message = double('message', send_to: nil, data: { request_id: 123 })
      allow(IB::Messages::Outgoing::RequestIds).to receive(:new).and_return(message)
      expect(fresh_ib.send_message(:RequestIds)).to eq(123)
    end

    it 'returns true when no request_id' do
      allow(fresh_ib).to receive(:connected?).and_return(true)
      allow(fresh_ib).to receive(:socket).and_return(double('socket'))
      message = double('message', send_to: nil, data: {})
      allow(IB::Messages::Outgoing::RequestIds).to receive(:new).and_return(message)
      expect(fresh_ib.send_message(:RequestIds)).to be true
    end

    it 'handles Errno::EPIPE by reconnecting and retrying' do
      allow(fresh_ib).to receive(:connected?).and_return(true)
      socket = double('socket')
      allow(fresh_ib).to receive(:socket).and_return(socket)
      message = double('message', data: {})
      allow(IB::Messages::Outgoing::RequestIds).to receive(:new).and_return(message)
      
      # First call raises EPIPE, second succeeds
      call_count = 0
      allow(message).to receive(:send_to) do
        call_count += 1
        raise Errno::EPIPE if call_count == 1
      end
      
      allow(fresh_ib).to receive(:reconnect)
      
      expect(fresh_ib.send_message(:RequestIds)).to be true
      expect(fresh_ib).to have_received(:reconnect)
    end
  end

  describe '#received?' do
    let(:fresh_ib) { IB::Connection.new }

    it 'returns false for empty received hash' do
      expect(fresh_ib.received?(:NextValidId)).to be false
    end

    it 'returns false when times > received size' do
      fresh_ib.received[:NextValidId] << :dummy1
      expect(fresh_ib.received?(:NextValidId, 2)).to be false
    end

    it 'returns true when times <= received size' do
      fresh_ib.received[:NextValidId] << :dummy1
      fresh_ib.received[:NextValidId] << :dummy2
      expect(fresh_ib.received?(:NextValidId, 2)).to be true
      expect(fresh_ib.received?(:NextValidId, 1)).to be true
    end
  end

  describe '#wait_for' do
    let(:fresh_ib) { IB::Connection.new }

    it 'processes messages when reader not running' do
      fresh_ib.instance_variable_set(:@reader_running, false)
      allow(fresh_ib).to receive(:process_messages)
      start_time = Time.now
      fresh_ib.wait_for(0.01) { false }
      expect(fresh_ib).to have_received(:process_messages).at_least(:once)
      expect(Time.now - start_time).to be >= 0.01
    end

    it 'sleeps when reader is running' do
      fresh_ib.instance_variable_set(:@reader_running, true)
      thread = Thread.new { sleep 1 }
      fresh_ib.instance_variable_set(:@reader_thread, thread)
      allow(fresh_ib).to receive(:sleep)
      start_time = Time.now
      fresh_ib.wait_for(0.01) { false }
      expect(fresh_ib).to have_received(:sleep).at_least(:once).with(0.05)
      expect(Time.now - start_time).to be >= 0.01
      thread.kill
    end
  end

  describe '#place_order' do
    let(:fresh_ib) { IB::Connection.new }

    before do
      allow(fresh_ib).to receive(:connected?).and_return(true)
      allow(fresh_ib).to receive(:send_message)
    end

    it 'assigns client_id to order' do
      fresh_ib.client_id = 1234
      fresh_ib.next_local_id = 100
      order = IB::Order.new
      contract = IB::Stock.new(symbol: 'AAPL')
      
      fresh_ib.place_order(order, contract)
      
      expect(order.client_id).to eq(1234)
    end

    it 'sets order.placed_at timestamp' do
      fresh_ib.next_local_id = 100
      order = IB::Order.new
      contract = IB::Stock.new(symbol: 'AAPL')
      
      before = Time.now - 1
      fresh_ib.place_order(order, contract)
      after = Time.now + 1
      
      expect(order.placed_at).to be_between(before, after)
    end

    it 'increments next_local_id after placing order' do
      fresh_ib.next_local_id = 100
      order = IB::Order.new
      contract = IB::Stock.new(symbol: 'AAPL')
      
      fresh_ib.place_order(order, contract)
      
      expect(fresh_ib.next_local_id).to eq(101)
    end

    it 'calls modify_order with order and contract' do
      fresh_ib.next_local_id = 100
      order = IB::Order.new
      contract = IB::Stock.new(symbol: 'AAPL')
      
      expect(fresh_ib).to receive(:modify_order).with(order, contract)
      fresh_ib.place_order(order, contract)
    end
  end

  describe '#cancel_order' do
    let(:fresh_ib) { IB::Connection.new }

    before do
      allow(fresh_ib).to receive(:connected?).and_return(true)
    end

    it 'calls send_message for single local_id' do
      expect(fresh_ib).to receive(:send_message).with(:CancelOrder, { local_id: 42 })
      fresh_ib.cancel_order(42)
    end

    it 'calls send_message for each local_id in multiple arguments' do
      expect(fresh_ib).to receive(:send_message).with(:CancelOrder, { local_id: 1 })
      expect(fresh_ib).to receive(:send_message).with(:CancelOrder, { local_id: 2 })
      expect(fresh_ib).to receive(:send_message).with(:CancelOrder, { local_id: 3 })
      fresh_ib.cancel_order(1, 2, 3)
    end

    it 'calls send_message for each local_id in array' do
      expect(fresh_ib).to receive(:send_message).with(:CancelOrder, { local_id: 4 })
      expect(fresh_ib).to receive(:send_message).with(:CancelOrder, { local_id: 5 })
      fresh_ib.cancel_order(4, 5)
    end
  end

  describe '#process_message error branches' do
    let(:fresh_ib) { IB::Connection.new }

    before do
      parser = double('parser')
      fresh_ib.instance_variable_set(:@parser, parser)
      fresh_ib.instance_variable_set(:@connected, true)
      allow(fresh_ib.logger).to receive(:fatal)
    end

    it 'raises error for message id zero' do
      allow(fresh_ib.instance_variable_get(:@parser)).to receive(:each).and_yield([0])
      expect { fresh_ib.send(:process_message) }.to raise_error(/Got unsupported message 0/)
    end

    it 'logs fatal when message type not found in Classes hash' do
      allow(fresh_ib.instance_variable_get(:@parser)).to receive(:each).and_yield([9999, 'data'])
      expect { fresh_ib.send(:process_message) }.to raise_error(/Got unsupported message/)
      expect(fresh_ib.logger).to have_received(:fatal)
    end
  end

  describe '#reconnect workflow state branches' do
    let(:fresh_ib) { IB::Connection.new }

    before do
      allow(fresh_ib.logger).to receive(:warn)
      allow(fresh_ib).to receive(:disconnect!)
      allow(fresh_ib).to receive(:unsubscribe)
      fresh_ib.instance_variable_set(:@subscribers, {})
    end

    it 'returns nil from virgin state' do
      fresh_ib.instance_variable_set(:@workflow_state, 'virgin')
      expect(fresh_ib.reconnect).to be_nil
    end

    it 'calls try_connection! from lean_mode state' do
      fresh_ib.instance_variable_set(:@workflow_state, 'lean_mode')
      expect(fresh_ib).to receive(:try_connection!)
      fresh_ib.reconnect
    end

    it 'calls try_connection! from ready state' do
      fresh_ib.instance_variable_set(:@workflow_state, 'ready')
      expect(fresh_ib).to receive(:try_connection!)
      fresh_ib.reconnect
    end

    it 'calls try_connection! from disconnected state' do
      fresh_ib.instance_variable_set(:@workflow_state, 'disconnected')
      expect(fresh_ib).to receive(:try_connection!)
      fresh_ib.reconnect
    end

    it 'calls activate_managed_accounts! from gateway_mode state' do
      fresh_ib.instance_variable_set(:@workflow_state, 'gateway_mode')
      expect(fresh_ib).to receive(:activate_managed_accounts!)
      fresh_ib.reconnect
    end

    it 'calls activate_managed_accounts! and initialize_managed_accounts! from account_based_operations state' do
      fresh_ib.instance_variable_set(:@workflow_state, 'account_based_operations')
      expect(fresh_ib).to receive(:activate_managed_accounts!)
      expect(fresh_ib).to receive(:initialize_managed_accounts!)
      fresh_ib.reconnect
    end

    it 'calls activate_managed_accounts!, initialize_managed_accounts!, and initialize_order_handling! from account_based_orderflow state' do
      fresh_ib.instance_variable_set(:@workflow_state, 'account_based_orderflow')
      expect(fresh_ib).to receive(:activate_managed_accounts!)
      expect(fresh_ib).to receive(:initialize_managed_accounts!)
      expect(fresh_ib).to receive(:initialize_order_handling!)
      fresh_ib.reconnect
    end
  end

  describe '#disconnect' do
    let(:fresh_ib) { IB::Connection.new }

    before do
      allow(fresh_ib).to receive(:socket).and_return(double('socket', close: nil))
    end

    it 'sets @connected to false' do
      fresh_ib.instance_variable_set(:@connected, true)
      fresh_ib.send(:disconnect)
      expect(fresh_ib.instance_variable_get(:@connected)).to be false
    end

    it 'joins reader thread if running' do
      thread = double('thread', alive?: true, join: nil)
      fresh_ib.instance_variable_set(:@reader_running, true)
      fresh_ib.instance_variable_set(:@reader_thread, thread)
      
      fresh_ib.send(:disconnect)
      
      expect(thread).to have_received(:join)
      expect(fresh_ib.instance_variable_get(:@reader_running)).to be false
    end

    it 'does not join thread if reader not running' do
      thread = double('thread')
      fresh_ib.instance_variable_set(:@reader_running, false)
      fresh_ib.instance_variable_set(:@reader_thread, thread)
      
      expect(thread).not_to receive(:join)
      fresh_ib.send(:disconnect)
    end
  end

  describe '#connected?' do
    let(:fresh_ib) { IB::Connection.new }

    it 'returns false when @connected is false' do
      fresh_ib.instance_variable_set(:@connected, false)
      expect(fresh_ib.connected?).to be false
    end

    it 'returns true when @connected is true' do
      fresh_ib.instance_variable_set(:@connected, true)
      expect(fresh_ib.connected?).to be true
    end
  end

  describe '#reader_running?' do
    let(:fresh_ib) { IB::Connection.new }

    it 'returns false when @reader_running is false' do
      fresh_ib.instance_variable_set(:@reader_running, false)
      fresh_ib.instance_variable_set(:@reader_thread, nil)
      expect(fresh_ib.send(:reader_running?)).to be false
    end

    it 'returns false when @reader_running is true but thread dead' do
      thread = double('thread', alive?: false)
      fresh_ib.instance_variable_set(:@reader_running, true)
      fresh_ib.instance_variable_set(:@reader_thread, thread)
      expect(fresh_ib.send(:reader_running?)).to be false
    end

    it 'returns true when @reader_running is true and thread alive' do
      thread = double('thread', alive?: true)
      fresh_ib.instance_variable_set(:@reader_running, true)
      fresh_ib.instance_variable_set(:@reader_thread, thread)
      expect(fresh_ib.send(:reader_running?)).to be true
    end
  end

  describe '#next_local_id' do
    let(:fresh_ib) { IB::Connection.new }

    it 'returns nil when not set' do
      expect(fresh_ib.next_local_id).to be_nil
    end

    it 'returns set value' do
      fresh_ib.next_local_id = 100
      expect(fresh_ib.next_local_id).to eq(100)
    end

    it 'aliases to next_order_id' do
      fresh_ib.next_local_id = 100
      expect(fresh_ib.next_order_id).to eq(100)
    end

    it 'allows assignment via next_order_id=' do
      fresh_ib.next_order_id = 200
      expect(fresh_ib.next_local_id).to eq(200)
    end
  end

  describe 'accessor methods' do
    let(:fresh_ib) { IB::Connection.new }

    it 'sets and gets socket' do
      socket = double('socket')
      fresh_ib.socket = socket
      expect(fresh_ib.socket).to eq(socket)
    end

    it 'sets and gets client_id' do
      fresh_ib.client_id = 1234
      expect(fresh_ib.client_id).to eq(1234)
    end

    it 'sets and gets server_version' do
      fresh_ib.server_version = '100'
      expect(fresh_ib.server_version).to eq('100')
    end

    it 'sets and gets client_version' do
      fresh_ib.client_version = '99'
      expect(fresh_ib.client_version).to eq('99')
    end

    it 'sets and gets host' do
      fresh_ib.host = 'localhost'
      expect(fresh_ib.host).to eq('localhost')
    end

    it 'sets and gets port' do
      fresh_ib.port = '4001'
      expect(fresh_ib.port).to eq('4001')
    end

    it 'sets and gets plugins' do
      fresh_ib.plugins = ['verify', 'symbols']
      expect(fresh_ib.plugins).to eq(['verify', 'symbols'])
    end
  end
end
