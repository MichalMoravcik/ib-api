require 'spec_helper'
require 'tmpdir'
require 'fileutils'

IB::Connection.current = Object.new.tap { |o| def o.activate_plugin(*); true; end; def o.logger; Logger.new(nil); end }
require_relative '../../../plugins/ib/symbols'
require_relative '../../../plugins/ib/symbols/abstract'
IB::Connection.current = nil

describe IB::Symbols do
  let(:temp_dir) { Dir.mktmpdir('ib-api-symbols') }

  before do
    IB::Symbols.set_origin(temp_dir)
  end

  after do
    FileUtils.remove_entry(temp_dir) if File.directory?(temp_dir)
  end

  describe '.set_origin' do
    it 'sets the symbol directory' do
      new_dir = Dir.mktmpdir
      IB::Symbols.set_origin(new_dir)
      expect(IB::Symbols.class_variable_get(:@@dir).to_s).to eq(Pathname.new(new_dir).to_s)
      FileUtils.remove_entry(new_dir)
    end

    it 'does not change origin for a non-existent directory' do
      original = IB::Symbols.class_variable_get(:@@dir)
      IB::Symbols.set_origin('/nonexistent/path/for/symbols')
      expect(IB::Symbols.class_variable_get(:@@dir)).to eq(original)
    end
  end

  describe '.allocate_collection' do
    it 'creates a new symbol collection module' do
      collection = IB::Symbols.allocate_collection(:test_stocks)
      expect(collection).to be_a(IB::Symbols)
      expect(IB::Symbols.const_defined?(:TestStocks)).to be true
    end

    it 'returns an existing collection' do
      first = IB::Symbols.allocate_collection(:test_stocks_2)
      second = IB::Symbols.allocate_collection(:test_stocks_2)
      expect(first.object_id).to eq(second.object_id)
    end

    it 'raises an error if the constant is already a non-Symbols class' do
      IB::Symbols.const_set(:NotASymbolCollection, Class.new)
      expect do
        IB::Symbols.allocate_collection(:NotASymbolCollection)
      end.to raise_error(IB::Error)
    end
  end

  describe '.read_collection and .store_collection' do
    it 'reads contracts from a YAML file' do
      collection = IB::Symbols.allocate_collection(:test_read)
      stock = IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD')
      collection.add_contract(:aapl, stock)

      reloaded = IB::Symbols.allocate_collection(:test_read)
      expect(reloaded.contracts).to have_key(:aapl)
      expect(reloaded.contracts[:aapl].symbol).to eq('AAPL')
    end
  end

  describe '#add_contract' do
    it 'adds a contract to the collection' do
      collection = IB::Symbols.allocate_collection(:test_add)
      stock = IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD')
      collection.add_contract(:aapl, stock)
      expect(collection.contracts).to have_key(:aapl)
    end

    it 'sets a description if none is provided' do
      collection = IB::Symbols.allocate_collection(:test_desc)
      stock = IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD', con_id: 12345)
      collection.add_contract(:aapl, stock)
      expect(collection.contracts[:aapl].description).not_to be_nil
    end
  end

  describe '#remove_contract' do
    it 'removes a contract from the collection' do
      collection = IB::Symbols.allocate_collection(:test_remove)
      stock = IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD')
      collection.add_contract(:aapl, stock)
      collection.remove_contract(:aapl)
      expect(collection.contracts).not_to have_key(:aapl)
    end
  end

  describe '#bunch' do
    it 'yields bunches of contracts' do
      collection = IB::Symbols.allocate_collection(:test_bunch)
      5.times do |i|
        collection.add_contract("stock_#{i}".to_sym, IB::Stock.new(symbol: "S#{i}"))
      end

      bunches = []
      collection.bunch(2, 0) { |bunch| bunches << bunch }
      expect(bunches.size).to be >= 2
      expect(bunches.flatten.size).to eq(5)
    end
  end

  describe '#to_human' do
    it 'returns the collection name' do
      collection = IB::Symbols.allocate_collection(:test_human)
      expect(collection.to_human).to eq('TestHuman')
    end
  end
end
