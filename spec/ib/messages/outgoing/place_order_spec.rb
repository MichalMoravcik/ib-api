require 'main_helper'

RSpec.describe IB::Messages::Outgoing  do


  context 'Newly instantiated Message' do

    subject do
      IB::Messages::Outgoing::PlaceOrder.new(
        local_id: 123,
        contract:  IB::Stock.new( symbol: 'F' ),
        order: IB::Order.new( total_quantity: 100, limit_price: 25, tif: :good_til_canceled ))
    end

    it { should be_an IB::Messages::Outgoing::PlaceOrder }
    its(:message_type) { is_expected.to eq :PlaceOrder }
    its(:message_id) { is_expected.to eq 3 }
#    its(:local_id) { is_expected.to eq 123 }

    it 'has class accessors as well' do
      expect( subject.class.message_type).to eq :PlaceOrder
      expect( subject.class.message_id).to eq 3
      expect( subject.class.version).to be_zero
    end


    it 'encodes correctly' do
      expect( subject.encode[0]). to eq [3, 123, []]                    # msg-id, local_id
      expect( subject.encode[1]). to eq ['', 'F','STK','','','',0.0,'SMART','','USD','','', "",""] #  contract
      expect( subject.encode[2] ).to eq [ nil, 100, "LMT",25,"" ] # basic order fields
      expect( subject.encode[3] ).to eq [ "DAY", nil, nil,"O",0,nil,true, 0, false, false, nil, 0, false, false ] # extended order fields
      expect( subject.encode[4]). to eq []                  # empty legs
      if subject.server_version < 177
        expect( subject.encode[5]). to eq  ["",0,nil,nil,[nil,nil,nil,nil]]       # advisory order fields
      else
        expect( subject.encode[5]). to eq  ["",0,nil,nil,[nil,nil,nil]]       # advisory order fields
      end
      expect( subject.encode[6 .. 12]). to eq ["",0,"",-1,0,nil,nil] # regulatory order fields
      expect( subject.encode[ 13  .. 22]). to eq [false, "", "", false, false, "", 0, [ nil, "", "", "", ""], false, ["", ""]]  # algo order fields -1-
      expect( subject.encode[23]). to eq ["",""]                  # empty delta neutral order fields
      expect( subject.encode[24 .. 25]). to eq [0,""]
      expect(subject.encode[26 .. -1]). to eq [  "", "", ["", "", "", "", "", ""], nil, [], false, nil, nil, false, [false], [""], "", false, "", false, [false, false], [], [0], ["", nil, nil, nil, nil, nil, nil], "", [nil, nil], nil, [[nil, nil], [nil, nil]], nil, nil, nil, "", nil, nil, nil, []]

# debug     puts  subject.encode[24 .. -1 ].then{|y| "\n[ #{y} ]"}
    end

    it 'raises error when contract is not a Contract' do
      msg = IB::Messages::Outgoing::PlaceOrder.new(
        local_id: 123,
        contract: 'not_a_contract',
        order: IB::Order.new(total_quantity: 100, limit_price: 25)
      )
      expect { msg.encode }.to raise_error(RuntimeError, /contract has to be specified/)
    end

    it 'uses order.contract when contract is not a Contract' do
      order = IB::Order.new(total_quantity: 100, limit_price: 25)
      order.contract = IB::Stock.new(symbol: 'IBM')
      msg = IB::Messages::Outgoing::PlaceOrder.new(
        local_id: 123,
        contract: nil,
        order: order
      )
      expect { msg.encode }.not_to raise_error
      expect(msg.encode[1][1]).to eq('IBM')
    end

    describe 'server version conditional fields' do
      let(:order) do
        o = IB::Order.new(total_quantity: 100, limit_price: 25)
        o.discretionary_up_to_limit_price = true
        o.use_price_management_algo = true
        o.duration = 60
        o.post_to_ats = 1
        o.auto_cancel_parent = true
        o.advanced_order_reject = true
        o.manual_order_time = '20210101'
        o.customer_account = 'acct123'
        o.professional_account = true
        o
      end
      let(:contract) { IB::Stock.new(symbol: 'F') }

      def build_msg(server_ver)
        IB::Messages::Outgoing::PlaceOrder.new(
          local_id: 123, contract: contract, order: order
        )
      end

      def stub_server_version(version)
        conn = instance_double(IB::Connection, server_version: version, logger: Logger.new('/dev/null'))
        allow(IB::Connection).to receive(:current).and_return(conn)
      end

      it 'includes discretionary_up_to_limit_price when server >= 148' do
        stub_server_version(148)
        msg = build_msg(148)
        encoded = msg.encode
        expect(encoded.flatten).to include(true)
      end

      it 'excludes discretionary_up_to_limit_price when server < 148' do
        stub_server_version(147)
        msg = build_msg(147)
        encoded = msg.encode
        expect(encoded).to be_an(Array)
      end

      it 'includes use_price_management_algo when server >= 151' do
        stub_server_version(151)
        msg = build_msg(151)
        encoded = msg.encode
        expect(encoded.flatten).to include(true)
      end

      it 'excludes use_price_management_algo when server < 151' do
        stub_server_version(150)
        msg = build_msg(150)
        encoded = msg.encode
        expect(encoded).to be_an(Array)
      end

      it 'includes duration when server >= 158' do
        stub_server_version(158)
        msg = build_msg(158)
        encoded = msg.encode
        expect(encoded.flatten).to include(60)
      end

      it 'excludes duration when server < 158' do
        stub_server_version(157)
        msg = build_msg(157)
        encoded = msg.encode
        expect(encoded.flatten).not_to include(60)
      end

      it 'includes post_to_ats when server >= 160' do
        stub_server_version(160)
        msg = build_msg(160)
        encoded = msg.encode
        expect(encoded.flatten).to include(1)
      end

      it 'excludes post_to_ats when server < 160' do
        stub_server_version(159)
        msg = build_msg(159)
        encoded = msg.encode
        expect(encoded.flatten).not_to include(1)
      end

      it 'includes auto_cancel_parent when server >= 162' do
        stub_server_version(162)
        msg = build_msg(162)
        encoded = msg.encode
        expect(encoded.flatten).to include(true)
      end

      it 'excludes auto_cancel_parent when server < 162' do
        stub_server_version(161)
        msg = build_msg(161)
        encoded = msg.encode
        expect(encoded.flatten).not_to include('auto_cancel_parent_value')
      end

      it 'includes advanced_order_reject when server >= 166' do
        stub_server_version(166)
        msg = build_msg(166)
        encoded = msg.encode
        expect(encoded.flatten).to include(true)
      end

      it 'excludes advanced_order_reject when server < 166' do
        stub_server_version(165)
        msg = build_msg(165)
        encoded = msg.encode
        expect(encoded.flatten).not_to include('advanced_order_reject_value')
      end

      it 'includes manual_order_time when server >= 169' do
        stub_server_version(169)
        msg = build_msg(169)
        encoded = msg.encode
        expect(encoded.flatten).to include('20210101')
      end

      it 'excludes manual_order_time when server < 169' do
        stub_server_version(168)
        msg = build_msg(168)
        encoded = msg.encode
        expect(encoded.flatten).not_to include('20210101')
      end

      it 'includes customer_account when server >= 183' do
        stub_server_version(183)
        msg = build_msg(183)
        encoded = msg.encode
        expect(encoded.flatten).to include('acct123')
      end

      it 'excludes customer_account when server < 183' do
        stub_server_version(182)
        msg = build_msg(182)
        encoded = msg.encode
        expect(encoded.flatten).not_to include('acct123')
      end

      it 'includes professional_account when server >= 184' do
        stub_server_version(184)
        msg = build_msg(184)
        encoded = msg.encode
        expect(encoded.flatten).to include(true)
      end

      it 'excludes professional_account when server < 184' do
        stub_server_version(183)
        msg = build_msg(183)
        encoded = msg.encode
        expect(encoded.flatten).not_to include('professional_account_value')
      end
    end
  end
end # describe IB::Messages:Outgoing
