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

describe IB::Symbols::Stocks do
  describe 'instantiation and attributes' do
    it 'creates ib_smart with correct attributes' do
      contract = IB::Symbols::Stocks.ib_smart
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('IBKR')
      expect(contract.currency).to eq('USD')
      expect(contract.description).to include('Interactive Brokers')
    end

    it 'creates ib with ISLAND exchange' do
      contract = IB::Symbols::Stocks.ib
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('IBKR')
      expect(contract.exchange).to eq('ISLAND')
    end

    it 'creates aapl with USD currency' do
      contract = IB::Symbols::Stocks.aapl
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('AAPL')
      expect(contract.currency).to eq('USD')
      expect(contract.description).to include('Apple')
    end

    it 'creates msft_conid by con_id' do
      contract = IB::Symbols::Stocks.msft_conid
      expect(contract).to be_a(IB::Stock)
      expect(contract.con_id).to eq(272093)
      expect(contract.currency).to eq('USD')
    end

    it 'creates msft by symbol' do
      contract = IB::Symbols::Stocks.msft
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('MSFT')
      expect(contract.description).to include('Microsoft')
    end

    it 'creates msft_island with primary exchange' do
      contract = IB::Symbols::Stocks.msft_island
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('MSFT')
      expect(contract.primary_exchange).to eq('ISLAND')
    end

    it 'creates vxx on ARCA exchange' do
      contract = IB::Symbols::Stocks.vxx
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('VXX')
      expect(contract.exchange).to eq('ARCA')
    end

    it 'creates wfc on NYSE with USD currency' do
      contract = IB::Symbols::Stocks.wfc
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('WFC')
      expect(contract.exchange).to eq('NYSE')
      expect(contract.currency).to eq('USD')
    end

    it 'creates sie with EUR currency' do
      contract = IB::Symbols::Stocks.sie
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('SIE')
      expect(contract.currency).to eq('EUR')
    end

    it 'creates wrong stock' do
      contract = IB::Symbols::Stocks.wrong
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('QEEUUE')
      expect(contract.exchange).to eq('NYSE')
    end
  end

  describe 'contract merging behavior' do
    it 'contracts hash is not empty' do
      expect(IB::Symbols::Stocks.contracts).not_to be_empty
    end

    it 'memoizes contracts' do
      contracts1 = IB::Symbols::Stocks.contracts
      contracts2 = IB::Symbols::Stocks.contracts
      expect(contracts1).to be(contracts2)
    end
  end
end

describe IB::Symbols::Futures do
  describe 'instantiation and attributes' do
    it 'creates ym mini-DJIA future' do
      contract = IB::Symbols::Futures.ym
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('YM')
      expect(contract.exchange).to eq('CBOT')
      expect(contract.currency).to eq('USD')
      expect(contract.expiry).not_to be_nil
      expect(contract.description).to include('Mini-DJIA')
    end

    it 'creates nq mini Nasdaq 100 with multiplier 20' do
      contract = IB::Symbols::Futures.nq
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('NQ')
      expect(contract.exchange).to eq('CME')
      expect(contract.multiplier).to eq(20)
    end

    it 'creates micro_nq with multiplier 2' do
      contract = IB::Symbols::Futures.micro_nq
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('MNQ')
      expect(contract.multiplier).to eq(2)
    end

    it 'creates es mini S&P 500 with multiplier 50' do
      contract = IB::Symbols::Futures.es
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('ES')
      expect(contract.multiplier).to eq(50)
    end

    it 'creates micro_es with multiplier 5' do
      contract = IB::Symbols::Futures.micro_es
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('MES')
      expect(contract.multiplier).to eq(5)
    end

    it 'creates russell with multiplier 5' do
      contract = IB::Symbols::Futures.russell
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('RTY')
      expect(contract.multiplier).to eq(5)
    end

    it 'creates micro_russell with multiplier 5' do
      contract = IB::Symbols::Futures.micro_russell
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('M2K')
      expect(contract.multiplier).to eq(5)
    end

    it 'creates zn 10yr Treasury with multiplier 1000' do
      contract = IB::Symbols::Futures.zn
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('ZN')
      expect(contract.multiplier).to eq(1000)
      expect(contract.exchange).to eq('CBOT')
    end

    it 'creates zb 30yr Treasury with multiplier 1000' do
      contract = IB::Symbols::Futures.zb
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('ZB')
      expect(contract.multiplier).to eq(1000)
    end

    it 'creates micro_dax with multiplier 1' do
      contract = IB::Symbols::Futures.micro_dax
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('DAX')
      expect(contract.exchange).to eq('EUREX')
      expect(contract.multiplier).to eq(1)
    end

    it 'creates mini_dax with multiplier 5' do
      contract = IB::Symbols::Futures.mini_dax
      expect(contract).to be_a(IB::Future)
      expect(contract.multiplier).to eq(5)
    end

    it 'creates dax with multiplier 25' do
      contract = IB::Symbols::Futures.dax
      expect(contract).to be_a(IB::Future)
      expect(contract.multiplier).to eq(25)
    end

    it 'creates stoxx with multiplier 10' do
      contract = IB::Symbols::Futures.stoxx
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('ESTX50')
      expect(contract.multiplier).to eq(10)
    end

    it 'creates mini_stoxx with multiplier 1' do
      contract = IB::Symbols::Futures.mini_stoxx
      expect(contract).to be_a(IB::Future)
      expect(contract.multiplier).to eq(1)
    end

    it 'creates micro_stoxx with multiplier 1' do
      contract = IB::Symbols::Futures.micro_stoxx
      expect(contract).to be_a(IB::Future)
      expect(contract.multiplier).to eq(1)
    end

    it 'creates gbp with correct multiplier' do
      contract = IB::Symbols::Futures.gbp
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('GBP')
      expect(contract.multiplier).to eq(62500)
    end

    it 'creates eur with correct multiplier' do
      contract = IB::Symbols::Futures.eur
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('EUR')
      expect(contract.multiplier).to eq(12500)
    end

    it 'creates jpy with correct multiplier' do
      contract = IB::Symbols::Futures.jpy
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('JPY')
      expect(contract.multiplier).to eq(12500000)
    end

    it 'creates hsi Hang Seng future' do
      contract = IB::Symbols::Futures.hsi
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('HSI')
      expect(contract.exchange).to eq('HKFE')
      expect(contract.currency).to eq('HKD')
      expect(contract.multiplier).to eq(50)
    end

    it 'creates vix future' do
      contract = IB::Symbols::Futures.vix
      expect(contract).to be_a(IB::Future)
      expect(contract.symbol).to eq('VIX')
      expect(contract.exchange).to eq('CFE')
      expect(contract.currency).to eq('USD')
    end
  end

  describe 'memoization' do
    it 'memoizes contracts hash' do
      contracts1 = IB::Symbols::Futures.contracts
      contracts2 = IB::Symbols::Futures.contracts
      expect(contracts1).to be(contracts2)
    end
  end
end

describe IB::Symbols::Options do
  describe 'instantiation and attributes' do
    it 'creates stoxx put option' do
      contract = IB::Symbols::Options.stoxx
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:ESTX50)
      expect(contract.right).to eq(:put)
      expect(contract.exchange).to eq('EUREX')
      expect(contract.trading_class).to eq('OESX')
    end

    it 'creates spx put option' do
      contract = IB::Symbols::Options.spx
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:SPX)
      expect(contract.right).to eq(:put)
      expect(contract.exchange).to eq('SMART')
      expect(contract.trading_class).to eq('SPX')
    end

    it 'creates spxw daily settled option' do
      contract = IB::Symbols::Options.spxw
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:SPX)
      expect(contract.trading_class).to eq('SPXW')
    end

    it 'creates xsp option' do
      contract = IB::Symbols::Options.xsp
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq('XSP')
      expect(contract.trading_class).to eq('XSP')
    end

    it 'creates spy option' do
      contract = IB::Symbols::Options.spy
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:SPY)
      expect(contract.right).to eq(:put)
      expect(contract.exchange).to eq('SMART')
    end

    it 'creates rut monthly option' do
      contract = IB::Symbols::Options.rut
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:RUT)
      expect(contract.trading_class).to eq('RUT')
    end

    it 'creates rutw weekly option' do
      contract = IB::Symbols::Options.rutw
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:RUT)
      expect(contract.description).to include('Weekly')
    end

    it 'creates russell option' do
      contract = IB::Symbols::Options.russell
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:RUT)
    end

    it 'creates mini_russell option' do
      contract = IB::Symbols::Options.mini_russell
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq(:MRUT)
    end

    it 'creates aapl call option with strike' do
      contract = IB::Symbols::Options.aapl
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq('AAPL')
      expect(contract.right).to eq('C')
      expect(contract.strike).to eq(150)
    end

    it 'creates ibm option' do
      contract = IB::Symbols::Options.ibm
      expect(contract).to be_a(IB::Option)
      expect(contract.symbol).to eq('IBM')
      expect(contract.exchange).to eq('SMART')
    end

    it 'creates ibm_lazy_expiry with strike but no expiry' do
      contract = IB::Symbols::Options.ibm_lazy_expiry
      expect(contract).to be_a(IB::Option)
      expect(contract.strike).to eq(180)
      expect(contract.expiry).to be_nil
    end

    it 'creates ibm_lazy_strike with expiry but no strike' do
      contract = IB::Symbols::Options.ibm_lazy_strike
      expect(contract).to be_a(IB::Option)
      expect(contract.expiry).not_to be_nil
      expect(contract.strike).to be_nil
    end
  end

  describe 'memoization' do
    it 'memoizes contracts hash' do
      contracts1 = IB::Symbols::Options.contracts
      contracts2 = IB::Symbols::Options.contracts
      expect(contracts1).to be(contracts2)
    end
  end
end

describe IB::Symbols::Index do
  describe 'instantiation and attributes' do
    it 'creates dax index' do
      contract = IB::Symbols::Index.dax
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('DAX')
      expect(contract.currency).to eq('EUR')
      expect(contract.exchange).to eq('EUREX')
    end

    it 'creates asx index' do
      contract = IB::Symbols::Index.asx
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('AP')
      expect(contract.currency).to eq('AUD')
    end

    it 'creates hsi index' do
      contract = IB::Symbols::Index.hsi
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('HSI')
      expect(contract.currency).to eq('HKD')
    end

    it 'creates minihsi index' do
      contract = IB::Symbols::Index.minihsi
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('MHI')
    end

    it 'creates stoxx index' do
      contract = IB::Symbols::Index.stoxx
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('ESTX50')
    end

    it 'creates spx index' do
      contract = IB::Symbols::Index.spx
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('SPX')
      expect(contract.exchange).to eq('CBOE')
    end

    it 'creates vhsi volatility index' do
      contract = IB::Symbols::Index.vhsi
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('VHSI')
      expect(contract.exchange).to eq('HKFE')
    end

    it 'creates vasx volatility index' do
      contract = IB::Symbols::Index.vasx
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('XVI')
    end

    it 'creates vstoxx volatility index' do
      contract = IB::Symbols::Index.vstoxx
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('V2TX')
      expect(contract.currency).to eq('EUR')
    end

    it 'creates vdax volatility index' do
      contract = IB::Symbols::Index.vdax
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('VDAX')
    end

    it 'creates vix volatility index' do
      contract = IB::Symbols::Index.vix
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('VIX')
      expect(contract.exchange).to eq('CBOE')
    end

    it 'creates volume index' do
      contract = IB::Symbols::Index.volume
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('VOL-NYSE')
    end

    it 'creates trin index' do
      contract = IB::Symbols::Index.trin
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('TRIN-NYSE')
    end

    it 'creates tick index' do
      contract = IB::Symbols::Index.tick
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('TICK-NYSE')
    end

    it 'creates a_d index' do
      contract = IB::Symbols::Index.a_d
      expect(contract).to be_a(IB::Index)
      expect(contract.symbol).to eq('AD-NYSE')
    end
  end
end

describe IB::Symbols::Forex do
  describe 'instantiation and attributes' do
    it 'creates eur usd forex pair' do
      contract = IB::Symbols::Forex.eurusd
      expect(contract).to be_a(IB::Forex)
      expect(contract.symbol).to eq('EUR')
      expect(contract.currency).to eq('USD')
      expect(contract.exchange).to eq('IDEALPRO')
      expect(contract.local_symbol).to eq('EUR.USD')
    end

    it 'creates gbp usd forex pair' do
      contract = IB::Symbols::Forex.gbpusd
      expect(contract).to be_a(IB::Forex)
      expect(contract.symbol).to eq('GBP')
      expect(contract.currency).to eq('USD')
    end

    it 'creates usd jpy forex pair' do
      contract = IB::Symbols::Forex.usdjpy
      expect(contract).to be_a(IB::Forex)
      expect(contract.symbol).to eq('USD')
      expect(contract.currency).to eq('JPY')
    end

    it 'creates aud usd forex pair' do
      contract = IB::Symbols::Forex.audusd
      expect(contract).to be_a(IB::Forex)
      expect(contract.symbol).to eq('AUD')
    end

    it 'creates all currency pairs' do
      expect(IB::Symbols::Forex.contracts).not_to be_empty
      # IDEALPRO pairs are symmetric (eurusd and usdeur are different)
      expect(IB::Symbols::Forex.eurusd).not_to be_nil
    end
  end

  describe 'define_contracts behavior' do
    it 'defines contracts via private define_contracts method' do
      # The private method should create @contracts
      expect(IB::Symbols::Forex.contracts).not_to be_empty
    end

    it 'memoizes contracts' do
      contracts1 = IB::Symbols::Forex.contracts
      contracts2 = IB::Symbols::Forex.contracts
      expect(contracts1).to be(contracts2)
    end
  end
end

describe IB::Symbols::Bonds do
  describe 'instantiation and attributes' do
    it 'creates abbey bond' do
      contract = IB::Symbols::Bonds.abbey
      expect(contract).to be_a(IB::Contract)
      expect(contract.symbol).to eq('ABBEY')
      expect(contract.sec_type).to eq(:bond)
      expect(contract.currency).to eq('USD')
      expect(contract.description).to include('ABBEY')
    end

    it 'creates ms bond' do
      contract = IB::Symbols::Bonds.ms
      expect(contract).to be_a(IB::Contract)
      expect(contract.symbol).to eq('MS')
      expect(contract.description).to include('Morgan Stanley')
    end

    it 'creates wag bond' do
      contract = IB::Symbols::Bonds.wag
      expect(contract).to be_a(IB::Contract)
      expect(contract.symbol).to eq('WAG')
      expect(contract.description).to include('Wallgreens')
    end
  end

  describe 'memoization' do
    it 'memoizes contracts hash' do
      contracts1 = IB::Symbols::Bonds.contracts
      contracts2 = IB::Symbols::Bonds.contracts
      expect(contracts1).to be(contracts2)
    end
  end
end

describe IB::Symbols::CFD do
  describe 'instantiation and attributes' do
    it 'creates dax cfd' do
      contract = IB::Symbols::CFD.dax
      expect(contract).to be_a(IB::Contract)
      expect(contract.symbol).to eq('IBDE30')
      expect(contract.sec_type).to eq(:cfd)
      expect(contract.currency).to eq('EUR')
      expect(contract.description).to include('DAX')
    end
  end
end

describe IB::Symbols::Commodity do
  describe 'instantiation and attributes' do
    it 'creates xau commodity (gold)' do
      contract = IB::Symbols::Commodity.xau
      expect(contract).to be_a(IB::Contract)
      expect(contract.symbol).to eq('XAUUSD')
      expect(contract.sec_type).to eq(:commodity)
      expect(contract.currency).to eq('USD')
      expect(contract.description).to include('Gold')
    end
  end
end

describe IB::Symbols::Combo do
  describe 'instantiation and attributes' do
    it 'creates stoxx_straddle' do
      contract = IB::Symbols::Combo.stoxx_straddle
      expect(contract).to be_a(IB::Straddle)
      expect(contract.symbol).to eq('ESTX50')
    end

    it 'creates stoxx_calendar' do
      contract = IB::Symbols::Combo.stoxx_calendar
      expect(contract).to be_a(IB::Calendar)
      expect(contract.symbol).to eq('ESTX50')
    end

    it 'creates stoxx_butterfly' do
      contract = IB::Symbols::Combo.stoxx_butterfly
      expect(contract).to be_a(IB::Butterfly)
      expect(contract.symbol).to eq('ESTX50')
    end

    it 'creates stoxx_vertical' do
      contract = IB::Symbols::Combo.stoxx_vertical
      expect(contract).to be_a(IB::Vertical)
      expect(contract.symbol).to eq('ESTX50')
    end

    it 'creates zn_calendar' do
      contract = IB::Symbols::Combo.zn_calendar
      expect(contract).to be_a(IB::Calendar)
      expect(contract.symbol).to eq('ZN')
    end

    it 'creates dbk_straddle as Bag' do
      contract = IB::Symbols::Combo.dbk_straddle
      expect(contract).to be_a(IB::Bag)
      expect(contract.symbol).to eq('DBK')
      expect(contract.combo_legs).not_to be_empty
    end

    it 'creates ib_mcd as Bag' do
      contract = IB::Symbols::Combo.ib_mcd
      expect(contract).to be_a(IB::Bag)
      expect(contract.symbol).to eq('IBKR,MCD')
      expect(contract.combo_legs.length).to eq(2)
    end

    it 'creates vix_calendar as Bag' do
      contract = IB::Symbols::Combo.vix_calendar
      expect(contract).to be_a(IB::Bag)
      expect(contract.symbol).to eq('VIX')
      expect(contract.exchange).to eq('CFE')
    end
  end

  describe 'memoization' do
    it 'memoizes contracts hash' do
      contracts1 = IB::Symbols::Combo.contracts
      contracts2 = IB::Symbols::Combo.contracts
      expect(contracts1).to be(contracts2)
    end
  end
end

describe IB::Symbols::Unspecified do
  it 'extends Symbols module' do
    expect(IB::Symbols::Unspecified).to be_a(Module)
    expect(IB::Symbols::Unspecified.contracts).to eq({})
  end
end
