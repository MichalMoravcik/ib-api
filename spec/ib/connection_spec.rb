require "spec_helper"

describe  IB::Connection do
  Given( :ib  ) { IB::Connection.new }
  Then { ib.is_a? IB::Connection }

  # Check if all Messages are defined
  # There are  51 Incoming Message classes
  Given( :in_classes ){ IB::Messages::Incoming::Classes }
  Then{  in_classes.is_a? Hash }
  Then{  in_classes.size == 51 }

  Given( :out_classes ){ IB::Messages::Outgoing::Classes }
  Then{  out_classes.is_a? Hash }
  Then{  out_classes.size == 53 }

  describe 'subscription management' do
    let(:ib) { IB::Connection.new }

    it 'subscribes to a message class' do
      id = ib.subscribe(:NextValidId) { |msg| msg }
      expect(id).to be_a(Integer)
    end

    it 'subscribes to a message class object' do
      id = ib.subscribe(IB::Messages::Incoming::NextValidId) { |msg| msg }
      expect(id).to be_a(Integer)
    end

    it 'unsubscribes by id' do
      id = ib.subscribe(:NextValidId) { |msg| msg }
      removed = ib.unsubscribe(id)
      expect(removed).not_to be_empty
    end
  end

  describe 'message sending' do
    let(:ib) { IB::Connection.new }
    let(:stub_socket) { IB::SocketStub.new }

    before do
      allow(IB::Socket).to receive(:open).and_return(stub_socket)
      ib.try_connection!
      ib.instance_variable_set(:@connected, true)
    end

    it 'sends a message by symbol' do
      expect { ib.send_message(:RequestIds) }.not_to raise_error
    end

    it 'sends a message object' do
      msg = IB::Messages::Outgoing::RequestIds.new
      expect { ib.send_message(msg) }.not_to raise_error
    end

    it 'raises when sending while disconnected' do
      ib.disconnect!
      expect { ib.send_message(:RequestIds) }.to raise_error(RuntimeError, /Not able to send/)
    end

    it 'places an order' do
      order = IB::Order.new(total_quantity: 100, limit_price: 150)
      contract = IB::Stock.new(symbol: 'AAPL', exchange: 'SMART')
      ib.next_local_id = 1
      id = ib.place_order(order, contract)
      expect(id).to eq(1)
      expect(order.local_id).to eq(1)
    end

    it 'modifies an order' do
      order = IB::Order.new(local_id: 5, total_quantity: 100)
      contract = IB::Stock.new(symbol: 'AAPL', exchange: 'SMART')
      id = ib.modify_order(order, contract)
      expect(id).to eq(5)
    end

    it 'cancels an order by local id' do
      expect { ib.cancel_order(42) }.not_to raise_error
    end
  end

  describe 'received message tracking' do
    let(:ib) { IB::Connection.new }

    it 'creates a received hash with method_missing' do
      ib.received[:NextValidId] << :dummy
      expect(ib.received?(:NextValidId)).to be true
    end

    it 'clears received messages' do
      ib.received[:NextValidId] << :dummy
      ib.clear_received(:NextValidId)
      expect(ib.received?(:NextValidId)).to be false
    end

    it 'clears all received messages when no types given' do
      ib.received[:NextValidId] << :dummy
      ib.received[:CurrentTime] << :dummy
      ib.clear_received
      expect(ib.received?(:NextValidId)).to be false
      expect(ib.received?(:CurrentTime)).to be false
    end
  end

  describe 'workflow helpers' do
    let(:ib) { IB::Connection.new }

    it 'exposes next_order_id alias' do
      ib.next_local_id = 7
      expect(ib.next_order_id).to eq(7)
    end

    it 'initializes with default workflow state' do
      expect(ib.workflow_state).to be_nil
    end
  end

  describe 'wait_for and satisfied?' do
    let(:ib) { IB::Connection.new }

    it 'returns immediately when condition is already met' do
      ib.received[:NextValidId] << :dummy
      expect { ib.wait_for(:NextValidId, 0.1) }.not_to raise_error
    end

    it 'waits until timeout when condition is not met' do
      allow(ib).to receive(:reader_running?).and_return(true)
      start = Time.now
      ib.wait_for(:NextValidId, 0.05)
      expect(Time.now - start).to be >= 0.05
    end

    it 'checks satisfied with callable condition' do
      expect(ib.send(:satisfied?, -> { true })).to be true
      expect(ib.send(:satisfied?, -> { false })).to be false
    end

    it 'checks satisfied with symbol condition' do
      ib.received[:NextValidId] << :dummy
      expect(ib.send(:satisfied?, :NextValidId)).to be true
    end

    it 'checks satisfied with array condition' do
      ib.received[:NextValidId] << :dummy
      expect(ib.send(:satisfied?, [:NextValidId, 1])).to be true
    end
  end

  describe 'reader_running? and random_id' do
    let(:ib) { IB::Connection.new }

    it 'returns false when no reader is running' do
      expect(ib.send(:reader_running?)).to be_falsey
    end

    it 'returns true when reader thread is alive' do
      ib.instance_variable_set(:@reader_running, true)
      ib.instance_variable_set(:@reader_thread, Thread.new { sleep 0.2 })
      expect(ib.send(:reader_running?)).to be true
      ib.instance_variable_get(:@reader_thread).kill
    end

    it 'generates a random subscriber id' do
      id = ib.send(:random_id)
      expect(id).to be_a(Integer)
      expect(id).to be < 1_000_000
    end
  end

  describe 'dispatch alias' do
    let(:ib) { IB::Connection.new }
    let(:stub_socket) { IB::SocketStub.new }

    before do
      allow(IB::Socket).to receive(:open).and_return(stub_socket)
      ib.try_connection!
      ib.instance_variable_set(:@connected, true)
    end

    it 'aliases dispatch to send_message' do
      expect(ib.method(:dispatch)).to eq(ib.method(:send_message))
    end
  end

  describe 'update_next_order_id' do
    let(:ib) { IB::Connection.new }

    it 'raises if next valid id cannot be retrieved' do
      allow(ib).to receive(:connected?).and_return(false)
      allow(ib).to receive(:try_connection!)
      allow(ib).to receive(:send_message)
      allow(ib).to receive(:unsubscribe)
      expect { ib.update_next_order_id }.to raise_error(RuntimeError, /Could not get NextValidID/)
    end
  end

  describe 'process_message and workflow' do
    let(:logger_output) { StringIO.new }
    let(:ib) { IB::Connection.new(logger: Logger.new(logger_output)) }
    let(:stub_socket) { IB::SocketStub.new }

    before do
      allow(IB::Socket).to receive(:open).and_return(stub_socket)
      ib.try_connection!
      ib.instance_variable_set(:@connected, true)
    end

    after do
      ib.instance_variable_set(:@reader_running, false)
      ib.instance_variable_get(:@reader_thread)&.kill
    end

    it 'processes a single decoded message and logs missing subscribers' do
      parser = double('parser')
      allow(parser).to receive(:each).and_yield([49, 1, 1_700_000_000])
      ib.instance_variable_set(:@parser, parser)
      ib.send(:process_message)
      expect(logger_output.string).to match(/No subscribers for message/)
    end

    it 'transitions workflow through try_connection!' do
      expect(ib.workflow_state).to eq('ready')
    end

    it 'disconnects and transitions state' do
      ib.disconnect!
      expect(ib.connected?).to be false
      expect(ib.workflow_state).to eq('disconnected')
    end

    it 'reconnects from disconnected state' do
      ib.disconnect!
      expect { ib.reconnect }.not_to raise_error
    end
  end

  describe 'subscribe with regexp' do
    let(:ib) { IB::Connection.new }

    it 'subscribes to message classes matching regexp' do
      id = ib.subscribe(/NextValid/) { |msg| msg }
      expect(id).to be_a(Integer)
    end
  end

  describe 'connection error handling' do
    let(:ib) { IB::Connection.new }
    let(:stub_socket) { IB::SocketStub.new }

    before do
      allow(IB::Socket).to receive(:open).and_return(stub_socket)
    end

    it 'raises on unsupported incoming message id' do
      parser = double('parser')
      allow(parser).to receive(:each).and_yield([9999])
      ib.instance_variable_set(:@parser, parser)
      ib.instance_variable_set(:@connected, true)
      expect { ib.send(:process_message) }
        .to raise_error(IB::TransmissionError, /Got unsupported message 9999/)
    end

    it 'raises when incoming message id is zero' do
      parser = double('parser')
      allow(parser).to receive(:each).and_yield([0])
      ib.instance_variable_set(:@parser, parser)
      ib.instance_variable_set(:@connected, true)
      expect { ib.send(:process_message) }
        .to raise_error(IB::TransmissionError, /Got unsupported message 0/)
    end


    it 'raises on transmission error while processing message' do
      parser = double('parser')
      allow(parser).to receive(:each).and_yield([49, 1])
      ib.instance_variable_set(:@parser, parser)
      ib.instance_variable_set(:@connected, true)
      allow(IB::Messages::Incoming::CurrentTime).to receive(:new).and_raise(IB::TransmissionError, 'broken')
      expect { ib.send(:process_message) }
        .to raise_error(IB::TransmissionError, 'broken')
    end
  end
end

describe "Connection tests" do
  it "connect to localhost", :integration do
    skip "Set TEST_ENV=real to run integration connection tests" unless ENV['TEST_ENV'] == 'real'
    c = IB::Connection.new host: OPTS[:connection][:host], port: OPTS[:connection][:port]
    expect( c ).to be_a IB::Connection
    c.try_connection!
    expect( c.connected? ).to be_truthy

  end
  it "connect to localhost with host:port syntax" do  # expected: no GUI-TWS is running on localhost
    c = IB::Connection.new host: '127.0.0.1:4001'
    expect( c ).to be_a IB::Connection
    expect{ c.try_connection! }.to raise_error Errno::ECONNREFUSED

  end
end

