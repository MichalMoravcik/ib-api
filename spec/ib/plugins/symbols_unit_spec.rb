require 'spec_helper'

# Save/restore Connection.current because symbols activates
# sub-plugins via IB::Connection.current during file load.
_original_connection = IB::Connection.current
IB::Connection.current = IB::Connection.new.tap { |c| c.instance_variable_set(:@socket, IB::SocketStub.new) }
require_relative '../../../plugins/ib/symbols'
IB::Connection.current = _original_connection

describe IB::Symbols do
  let(:mod) do
    m = Module.new
    m.extend(IB::Symbols)
    m
  end

  describe '#hardcoded?' do
    it 'returns true if no yml_file method' do
      expect(mod.hardcoded?).to be true
    end

    it 'returns false if yml_file method exists' do
      m = Module.new do
        extend IB::Symbols
        singleton_class.define_method(:yml_file) { 'x' }
      end
      expect(m.hardcoded?).to be false
    end
  end

  describe '#contracts' do
    it 'returns empty hash by default' do
      expect(mod.contracts).to eq({})
    end

    it 'memoizes the hash' do
      mod.contracts[:a] = 1
      expect(mod.contracts[:a]).to eq(1)
    end
  end

  describe '#all' do
    it 'returns sorted contract keys' do
      mod.contracts[:b] = 1
      mod.contracts[:a] = 2
      expect(mod.all).to eq([:a, :b])
    end
  end

  describe '#print_all' do
    it 'prints sorted contracts with descriptions' do
      contract = IB::Stock.new(symbol: 'A')
      mod.contracts[:a] = contract
      expect { mod.print_all }.to output(/a/).to_stdout
    end
  end

  describe '#[]' do
    it 'returns known contract' do
      contract = IB::Stock.new(symbol: 'A')
      mod.contracts[:a] = contract
      expect(mod[:a]).to eq(contract)
    end

    it 'raises for unknown symbol' do
      expect { mod[:unknown] }.to raise_error(IB::SymbolError)
    end
  end

  describe '#method_missing' do
    it 'returns known symbol as method' do
      contract = IB::Stock.new(symbol: 'A')
      mod.contracts[:a] = contract
      expect(mod.a).to eq(contract)
    end

    it 'raises for unknown symbol without args' do
      expect { mod.unknown }.to raise_error(IB::SymbolError)
    end

    it 'raises when called with args' do
      expect { mod.a(:x) }.to raise_error(IB::Error)
    end
  end
end
