require 'main_helper'

describe IB::Messages::Outgoing  do
  before( :all ) do
    establish_connection
    ib = IB::Connection.current
    ib.activate_plugin :symbols
  end

  let( :siemens ){   IB::Stock.new symbol: 'MSFT', currency: 'USD', exchange: 'SMART' }
  context 'RequestMarketData for a US-Stock' do

    subject do
      IB::Messages::Outgoing::RequestMarketData.new( :contract => siemens,
                                                     :snapshot => true,
                                                     :id => 3884 )
    end

    it { is_expected.to be_an IB::Messages::Outgoing::RequestMarketData }
    its(:message_type) { is_expected.to eq :RequestMarketData }
    its(:message_id) { is_expected.to eq 1 }
    its(:data) { is_expected.to eq({:snapshot=>true, :contract=> siemens, :id => 3884} )}
    its(:to_human) { is_expected.to match  /RequestMarketData/ }

    it 'has class accessors as well' do
      expect( subject.class.message_type).to eq :RequestMarketData
      expect( subject.class.message_id).to eq 1
      expect( subject.class.version).to eq 11
    end

    it 'encodes into an Array' do
      puts "RAW"
      puts subject.encode.then{|y| "[#{y}]" }
      expect( subject.encode[0]).to eq  [1, 11]                      # messageID, Version
      expect( subject.encode[2][0]).to be_a Numeric                  # request id
      expect( subject.encode[2][1]).to eq siemens.serialize_short    # serialized contract
      expect( subject.encode[2][2]).to be_empty                      # no legs
      expect( subject.encode[2][3]).to be_falsy                      # no delta neutral contract
      expect( subject.encode[2][4]).to be_empty                      # no Tick list
      expect( subject.encode[2][5]).to be_truthy                     # snapshot
      expect( subject.encode[2][6]).to be_falsy                      # regulatory snapshot
      expect( subject.encode[2][7]).to be_empty                      # options

    end
#
    it 'that is flattened before sending it over socket to IB server' do
      expect(subject.preprocess[0..1]).to eq [1, 11]
      expect(subject.preprocess[2]).to eq 3884
    end

    it 'and has a correct #to_s representation' do
      expect(subject.to_s).to include('MSFT')
      expect(subject.to_s).to include('STK')
    end

  end
  context 'RequestMarketData for a Stock Spread' do

    subject do
      IB::Messages::Outgoing::RequestMarketData.new( :contract => IB::Symbols::Combo.ib_mcd,
                                                     :snapshot => true,
                                                     :id => 3884 )
    end

    it 'encodes into an Array' do
      puts "RAW"
      puts subject.encode.then{|y| "[#{y}]" }
    end
  end

  context 'RequestMarketData with tick_list as array' do
    subject do
      IB::Messages::Outgoing::RequestMarketData.new(
        contract: siemens,
        tick_list: ['100', '101'],
        id: 3885
      )
    end

    it 'stores tick list array as-is' do
      expect(subject.data[:tick_list]).to eq ['100', '101']
    end
  end

  context 'RequestMarketData with tick_list as string' do
    subject do
      IB::Messages::Outgoing::RequestMarketData.new(
        contract: siemens,
        tick_list: '100,101',
        id: 3886
      )
    end

    it 'keeps string tick list as-is' do
      expect(subject.data[:tick_list]).to eq '100,101'
    end
  end

  context 'RequestMarketData with nil tick_list' do
    subject do
      IB::Messages::Outgoing::RequestMarketData.new(
        contract: siemens,
        tick_list: nil,
        id: 3887
      )
    end

    it 'keeps nil tick_list as nil' do
      expect(subject.data[:tick_list]).to be_nil
    end
  end
end # describe IB::Messages:Outgoing
