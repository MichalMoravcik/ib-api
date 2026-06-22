require 'account_helper'



describe IB::Messages::Incoming do


  context 'Message received from IB', :connected => true do
    before(:all) do
      establish_connection
      ib = IB::Connection.current

      ib.send_message :RequestFA, fa_data_type: 3   # alias

      ib.wait_for :ReceiveFA
    end

    after(:all) { close_connection }

    subject { IB::Connection.current.received[:ReceiveFA].first }

    it_behaves_like 'ReceiveFA message'

    it_behaves_like 'Valid Account Object' do
      let( :the_account_object ){ IB::Connection.current.received[:ReceiveFA].first.accounts.first  }
    end
  end #

  context 'ReceiveFA with array of aliases (Groups)' do
    subject do
      IB::Messages::Incoming::ReceiveFA.new(
        version: 1,
        type: 1,
        xml: {
          ListOfAccountAliases: {
            AccountAlias: [
              { account: 'ACC1', alias: 'Alias1' },
              { account: 'ACC2', alias: 'Alias2' }
            ]
          }
        }
      )
    end

    it 'returns array of Account objects' do
      expect(subject.accounts).to be_an Array
      expect(subject.accounts.size).to eq 2
      expect(subject.accounts.first).to be_a IB::Account
    end

    its(:to_human) { is_expected.to match /FA:/ }
  end

  context 'ReceiveFA with single hash alias (sole FA)' do
    subject do
      IB::Messages::Incoming::ReceiveFA.new(
        version: 1,
        type: 3,
        xml: {
          ListOfAccountAliases: {
            AccountAlias: { account: 'SOLO_ACC', alias: 'MyAccount' }
          }
        }
      )
    end

    it 'returns array with single Account object' do
      expect(subject.accounts).to be_an Array
      expect(subject.accounts.size).to eq 1
      expect(subject.accounts.first).to be_a IB::Account
      expect(subject.accounts.first.account).to eq 'SOLO_ACC'
    end
  end
end # describe IB::Messages:Incoming
