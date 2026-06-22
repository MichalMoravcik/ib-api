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
  end
end
