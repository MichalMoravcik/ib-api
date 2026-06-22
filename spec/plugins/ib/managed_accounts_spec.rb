# frozen_string_literal: true

require 'spec_helper'

describe 'ManagedAccounts plugin' do
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

  let(:user_account) { IB::Account.new(account: 'DU167348', type: 'User') }
  let(:advisor_account) { IB::Account.new(account: 'DF167348', type: 'Advisor') }

  before do
    allow(IB::Connection).to receive(:current).and_return(connection)
    require_relative '../../../plugins/ib/managed-accounts'
    connection.class.send(:include, IB::ManagedAccounts)
  end

  def subscribers
    connection.send(:subscribers)
  end

  describe '#clients' do
    before { connection.instance_variable_set(:@accounts, [user_account, advisor_account]) }

    it 'returns only user accounts' do
      expect(connection.clients).to contain_exactly(user_account)
    end
  end

  describe '#advisor' do
    before { connection.instance_variable_set(:@accounts, [advisor_account, user_account]) }

    it 'returns the first account' do
      expect(connection.advisor).to eq(advisor_account)
    end
  end

  describe '#fa?' do
    it 'is false when advisor and first client are identical' do
      connection.instance_variable_set(:@accounts, [user_account])
      expect(connection).not_to be_fa
    end

    it 'is true when advisor differs from first client' do
      connection.instance_variable_set(:@accounts, [advisor_account, user_account])
      expect(connection).to be_fa
    end
  end

  describe '#all_contracts' do
    let(:aapl) { factory.create_stock(symbol: 'AAPL', con_id: 1) }
    let(:msft) { factory.create_stock(symbol: 'MSFT', con_id: 2) }

    before do
      user_account.contracts = [aapl, msft]
      advisor_account.contracts = [aapl]
      connection.instance_variable_set(:@accounts, [user_account, advisor_account])
    end

    it 'returns unique contracts across all clients' do
      expect(connection.all_contracts).to contain_exactly(aapl, msft)
    end
  end

  describe '#account_data' do
    before { connection.instance_variable_set(:@accounts, [user_account, advisor_account]) }

    it 'yields a single account by id' do
      yielded = nil
      connection.send(:account_data, 'DU167348') { |a| yielded = a }
      expect(yielded).to eq(user_account)
    end

    it 'yields a single account when passed an Account object' do
      yielded = nil
      connection.send(:account_data, advisor_account) { |a| yielded = a }
      expect(yielded).to eq(advisor_account)
    end

    it 'yields all accounts when no argument is given' do
      yielded = []
      connection.send(:account_data) { |a| yielded << a }
      expect(yielded).to contain_exactly(user_account, advisor_account)
    end
  end

  describe '#subscribe_account_updates' do
    before { connection.instance_variable_set(:@accounts, [user_account]) }

    it 'registers AccountValue, PortfolioValue and AccountDownloadEnd subscribers' do
      connection.send(:subscribe_account_updates)
      expect(subscribers.keys).to include(
        IB::Messages::Incoming::AccountValue,
        IB::Messages::Incoming::PortfolioValue,
        IB::Messages::Incoming::AccountDownloadEnd
      )
    end

    context 'AccountValue handler' do
      let(:subscriber) do
        connection.send(:subscribe_account_updates)
        subscribers[IB::Messages::Incoming::AccountValue].values.first
      end

      let(:msg) do
        IB::Messages::Incoming::AccountValue.new(
          account_value: { key: 'CashBalance', value: '1000', currency: 'USD' },
          account: 'DU167348'
        )
      end

      it 'appends the account value to the account' do
        subscriber.call(msg)
        expect(user_account.account_values).not_to be_empty
      end

      it 'updates last_updated timestamp' do
        expect { subscriber.call(msg) }.to change { user_account.last_updated }
      end
    end

    context 'PortfolioValue handler' do
      let(:subscriber) do
        connection.send(:subscribe_account_updates)
        subscribers[IB::Messages::Incoming::PortfolioValue].values.first
      end

      let(:contract) { factory.create_stock(symbol: 'AAPL', con_id: 123) }
      let(:msg) do
        IB::Messages::Incoming::PortfolioValue.new(
          contract: contract.attributes.merge(sec_type: 'STK'),
          portfolio_value: { position: 10, market_price: 150.0, market_value: 1500.0, average_cost: 145.0, unrealized_pnl: 50.0, realized_pnl: 0.0 },
          account: 'DU167348'
        )
      end

      it 'adds the contract to the account' do
        subscriber.call(msg)
        expect(user_account.contracts.map(&:con_id)).to include(123)
      end

      it 'adds a portfolio value' do
        subscriber.call(msg)
        expect(user_account.portfolio_values.size).to eq(1)
      end

      it 'replaces an existing portfolio value for the same contract' do
        user_account.portfolio_values << IB::PortfolioValue.new(position: 5, contract: contract)
        subscriber.call(msg)
        expect(user_account.portfolio_values.size).to eq(1)
        expect(user_account.portfolio_values.first.position).to eq(10)
      end
    end

    context 'AccountDownloadEnd handler' do
      let(:subscriber) do
        connection.send(:subscribe_account_updates)
        subscribers[IB::Messages::Incoming::AccountDownloadEnd].values.first
      end

      let(:msg) do
        IB::Messages::Incoming::AccountDownloadEnd.new(account_name: 'DU167348')
      end

      it 'marks the account as connected when enough account values are present' do
        11.times do |i|
          user_account.account_values << IB::AccountValue.new(key: "key#{i}", value: i.to_s, currency: 'USD')
        end
        subscriber.call(msg)
        expect(user_account.connected).to be true
      end

      it 'raises when too few account values are present' do
        expect { subscriber.call(msg) }.to raise_error(IB::TransmissionError)
      end
    end
  end

  describe '#get_account_data' do
    let(:closed_queue) do
      q = Queue.new
      allow(q).to receive(:pop)
      allow(q).to receive(:close)
      allow(q).to receive(:closed?).and_return(true)
      q
    end

    before do
      connection.instance_variable_set(:@accounts, [user_account])
      allow(connection).to receive(:send_message)
      allow(connection).to receive(:subscribe).and_return(1)
      allow(connection).to receive(:unsubscribe)
      allow(Queue).to receive(:new).and_return(closed_queue)
    end

    it 'returns early and warns when no accounts are present' do
      connection.instance_variable_set(:@accounts, [])
      expect(connection.logger).to receive(:warn)
      connection.get_account_data
    end

    it 'resets portfolio_values and account_values for the account' do
      user_account.portfolio_values = [IB::PortfolioValue.new]
      user_account.account_values = [IB::AccountValue.new]
      begin
        connection.get_account_data
      rescue IB::TransmissionError
      end
      expect(user_account.portfolio_values).to be_empty
      expect(user_account.account_values).to be_empty
    end

    it 'raises IB::TransmissionError when the download queue closes' do
      expect { connection.get_account_data(user_account) }.to raise_error(IB::TransmissionError)
    end

    it 'does not re-request if last update was recent' do
      user_account.update_attribute(:last_updated, Time.now)
      expect(connection).not_to receive(:send_message).with(:RequestAccountData, subscribe: true, account_code: 'DU167348')
      connection.get_account_data(user_account)
    end

    it 'accepts an account id string' do
      expect { connection.get_account_data('DU167348') }.to raise_error(IB::TransmissionError)
    end

    it 'raises if the resolved account is not an IB::Account' do
      expect { connection.get_account_data('MISSING') }.to raise_error(IB::Error)
    end
  end

  describe '#initialize_managed_accounts' do
    let(:ready_queue) do
      q = Queue.new
      allow(q).to receive(:pop).and_return(true)
      allow(q).to receive(:close)
      q
    end

    before do
      allow(connection).to receive(:connected?).and_return(false)
      allow(connection).to receive(:try_connection!)
      allow(connection).to receive(:disconnect!)
      allow(connection).to receive(:send_message)
      allow(connection).to receive(:unsubscribe)
      allow(Queue).to receive(:new).and_return(ready_queue)
      connection.instance_variable_set(:@accounts, [])
    end

    it 'connects if not already connected' do
      allow(connection).to receive(:subscribe).and_return(1)
      expect(connection).to receive(:try_connection!)
      connection.send(:initialize_managed_accounts)
    end

    it 'disconnects first when force is true' do
      allow(connection).to receive(:connected?).and_return(true)
      allow(connection).to receive(:subscribe).and_return(1)
      expect(connection).to receive(:disconnect!)
      connection.send(:initialize_managed_accounts, force: true)
    end

    it 'sets up ManagedAccounts and ReceiveFA subscribers' do
      expect(connection).to receive(:subscribe).with(:ReceiveFA).and_return(2)
      expect(connection).to receive(:subscribe).with(:ManagedAccounts).and_return(3)
      expect(connection).to receive(:subscribe).with(:Alert).and_return(4)
      connection.send(:initialize_managed_accounts)
    end

    it 'populates @accounts from a ManagedAccounts message' do
      expect(connection).to receive(:subscribe).with(:ManagedAccounts).and_wrap_original do |_m, *_args, &block|
        msg = IB::Messages::Incoming::ManagedAccounts.new(accounts_list: 'DU167348,DF167348')
        block.call(msg)
        3
      end
      allow(connection).to receive(:subscribe).with(:ReceiveFA).and_return(2)
      allow(connection).to receive(:subscribe).with(:Alert).and_return(4)
      connection.send(:initialize_managed_accounts)
      expect(connection.instance_variable_get(:@accounts).map(&:account)).to contain_exactly('DU167348', 'DF167348')
    end

    it 'applies aliases from ReceiveFA' do
      captured = nil
      receive_fa_block = nil
      expect(connection).to receive(:subscribe).with(:ReceiveFA).and_wrap_original do |_m, *_args, &block|
        receive_fa_block = block
        2
      end
      expect(connection).to receive(:subscribe).with(:ManagedAccounts).and_wrap_original do |_m, *_args, &block|
        msg = IB::Messages::Incoming::ManagedAccounts.new(accounts_list: 'DU167348')
        block.call(msg)
        captured = connection.instance_variable_get(:@accounts).first
        receive_fa_block.call(
          double('receive_fa', accounts: [IB::Account.new(account: 'DU167348', alias: 'Demo')])
        )
        3
      end
      allow(connection).to receive(:subscribe).with(:Alert).and_return(4)
      connection.send(:initialize_managed_accounts)
      expect(captured.alias).to eq('Demo')
    end
  end

  describe '#activate_managed_accounts alias' do
    it 'aliases to subscribe_account_updates' do
      expect(connection.method(:activate_managed_accounts)).to eq connection.method(:subscribe_account_updates)
    end
  end
end
