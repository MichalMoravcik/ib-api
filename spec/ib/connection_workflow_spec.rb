require "spec_helper"

describe IB::Connection do
  describe 'workflow state management' do
    let(:ib) { IB::Connection.new }

    it 'starts with nil workflow_state' do
      # New connection without try_connection! starts in nil state
      # The workflow gem initializes on first event
      expect(ib.workflow_state).to be_nil
    end

    describe 'state transitions from virgin' do
      it 'transitions virgin to ready via try_connection' do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        expect(ib.workflow_state).to eq 'ready'
      end

      it 'transitions virgin to gateway_mode via activate_managed_accounts' do
        ib.activate_managed_accounts!
        expect(ib.workflow_state).to eq 'gateway_mode'
      end

      it 'transitions virgin to lean_mode via collect_data' do
        ib.collect_data!
        expect(ib.workflow_state).to eq 'lean_mode'
      end
    end

    describe 'transitions from lean_mode' do
      before do
        ib.collect_data!
        expect(ib.workflow_state).to eq 'lean_mode'
      end

      it 'transitions lean_mode to ready via try_connection' do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        expect(ib.workflow_state).to eq 'ready'
      end
    end

    describe 'transitions from gateway_mode' do
      before do
        ib.activate_managed_accounts!
        expect(ib.workflow_state).to eq 'gateway_mode'
      end

      it 'transitions gateway_mode to ready via try_connection' do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        expect(ib.workflow_state).to eq 'ready'
      end

      it 'transitions gateway_mode to account_based_operations via initialize_managed_accounts' do
        ib.initialize_managed_accounts!
        expect(ib.workflow_state).to eq 'account_based_operations'
      end
    end

    describe 'transitions from ready' do
      before do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        expect(ib.workflow_state).to eq 'ready'
      end

      it 'transitions ready to account_based_operations via initialize_managed_accounts' do
        ib.initialize_managed_accounts!
        expect(ib.workflow_state).to eq 'account_based_operations'
      end

      it 'transitions ready to disconnected via disconnect' do
        ib.disconnect!
        expect(ib.workflow_state).to eq 'disconnected'
      end
    end

    describe 'transitions from disconnected' do
      before do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        ib.disconnect!
        expect(ib.workflow_state).to eq 'disconnected'
      end

      it 'transitions disconnected to ready via try_connection' do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        expect(ib.workflow_state).to eq 'ready'
      end

      it 'transitions disconnected to gateway_mode via activate_managed_accounts' do
        ib.activate_managed_accounts!
        expect(ib.workflow_state).to eq 'gateway_mode'
      end
    end

    describe 'transitions from account_based_operations' do
      before do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        ib.initialize_managed_accounts!
        expect(ib.workflow_state).to eq 'account_based_operations'
      end

      it 'transitions account_based_operations to disconnected via disconnect' do
        ib.disconnect!
        expect(ib.workflow_state).to eq 'disconnected'
      end

      it 'transitions account_based_operations to account_based_orderflow via initialize_order_handling' do
        ib.initialize_order_handling!
        expect(ib.workflow_state).to eq 'account_based_orderflow'
      end
    end

    describe 'transitions from account_based_orderflow' do
      before do
        stub_socket = IB::SocketStub.new
        stub_socket.add_message("165\n2024-01-01T00:00:00+00:00\n")
        allow(IB::Socket).to receive(:open).and_return(stub_socket)

        ib.try_connection!
        ib.initialize_managed_accounts!
        ib.initialize_order_handling!
        expect(ib.workflow_state).to eq 'account_based_orderflow'
      end

      it 'transitions account_based_orderflow to disconnected via disconnect' do
        ib.disconnect!
        expect(ib.workflow_state).to eq 'disconnected'
      end
    end

    describe 'on_transition callback' do
      it 'logs workflow state transitions' do
        expect(ib.logger).to receive(:warn).at_least(:once)
        ib.activate_managed_accounts!
      end
    end
  end
end
