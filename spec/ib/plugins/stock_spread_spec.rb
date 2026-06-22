require 'spec_helper'
require_relative '../../../plugins/ib/symbols/forex'

IB::Connection.current = Object.new.tap { |o| def o.activate_plugin(*); true; end; def o.logger; Logger.new(nil); end; def o.plugins; []; end }
require_relative '../../../plugins/ib/verify'

module IB
  module SpreadPrototype
    def build from:, **fields
    end

    def initialize_spread ref_contract = nil, **attributes
      error "Initializing of Spread failed – contract is missing" unless ref_contract.is_a?(IB::Contract)
      the_contract = ref_contract.merge(**attributes).verify.first
      error "Underlying for Spread is not valid: #{ref_contract.to_human}" if the_contract.nil?
      the_spread = IB::Spread.new the_contract.attributes.slice(:exchange, :symbol, :currency)
      error "Initializing of Spread failed – Underling is no Contract" if the_spread.nil?
      yield the_spread if block_given?
      the_spread
    end

    def requirements; {}; end
    def defaults; {}; end
    def optional; {}; end

    def parameters
      the_output = ->(var){ var.empty? ? "none" : var.map{|x| x.join(" --> ") }.join("\n\t: ")}
      "Required : " + the_output[requirements] + "\n --------------- \n" +
      "Optional : " + the_output[optional] + "\n --------------- \n"
    end
  end
end

require_relative '../../../plugins/ib/spread-prototypes/stock-spread'

describe IB::StockSpread do
  let(:stock_a) { IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD', con_id: 12345) }
  let(:stock_b) { IB::Stock.new(symbol: 'MSFT', exchange: 'SMART', currency: 'USD', con_id: 67890) }

  before do
    IB::Connection.current = double('connection', activate_plugin: true, logger: Logger.new(nil))
    allow(IB::Stock).to receive(:new).and_call_original
  end

  after do
    IB::Connection.current = nil
  end

  describe '.fabricate' do
    before do
      allow(IB::Stock).to receive(:new).and_call_original
      allow_any_instance_of(IB::Stock).to receive(:verify).and_return([stock_a])
    end

    it 'creates a spread from two stock symbols' do
      spread = IB::StockSpread.fabricate('AAPL', 'MSFT')
      expect(spread).to be_an(IB::Spread)
      expect(spread.legs.size).to eq(2)
      expect(spread.symbol).to include('AAPL')
    end

    it 'creates a spread from two stock objects' do
      allow_any_instance_of(IB::Stock).to receive(:verify).and_return([stock_b])
      spread = IB::StockSpread.fabricate(stock_a, stock_b)
      expect(spread).to be_an(IB::Spread)
      expect(spread.legs.size).to eq(2)
    end

    it 'applies a custom ratio' do
      spread = IB::StockSpread.fabricate('AAPL', 'MSFT', ratio: [1, -2])
      expect(spread).to be_an(IB::Spread)
      expect(spread.combo_legs.map(&:weight)).to eq([1, -2])
    end

    it 'raises an error with non-stock inputs' do
      forex = IB::Forex.new(symbol: 'EUR', exchange: 'IDEALPRO', currency: 'USD', con_id: 99999)
      allow(IB::Stock).to receive(:new).with(symbol: 'EURUSD').and_return(forex)
      allow(forex).to receive(:merge).and_return(forex)
      allow(forex).to receive(:verify).and_return([forex])

      expect { IB::StockSpread.fabricate('EURUSD') }.to raise_error(IB::Error)
    end

    it 'raises an error with more than two underlyings' do
      stock_c = IB::Stock.new(symbol: 'GOOGL', exchange: 'SMART', currency: 'USD', con_id: 11111)

      expect { IB::StockSpread.fabricate(stock_a, stock_b, stock_c) }.to raise_error(IB::Error)
    end
  end

  describe '.the_description' do
    before do
      allow(IB::Stock).to receive(:new).and_call_original
      first = true
      allow_any_instance_of(IB::Stock).to receive(:verify) do |stock|
        first ? (first = false; [stock_a]) : [stock_b]
      end
    end

    it 'formats the spread description' do
      spread = IB::StockSpread.fabricate('AAPL', 'MSFT')
      expect(spread.description).to include('StockSpread')
      expect(spread.description).to include('AAPL')
      expect(spread.description).to include('MSFT')
    end
  end
end
