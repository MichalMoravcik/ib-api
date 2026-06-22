require 'spec_helper'

RSpec.describe IB::Spread do
  let(:stock_a) { IB::Stock.new(symbol: 'AAPL', con_id: 1, exchange: 'SMART') }
  let(:stock_b) { IB::Stock.new(symbol: 'MSFT', con_id: 2, exchange: 'SMART') }

  describe '.transform_distance' do
    it 'passes through absolute YYYYMM values' do
      expect(IB::Spread.transform_distance('202401', '202402')).to eq(202_402)
    end

    it 'passes through absolute YYYYMMDD values' do
      expect(IB::Spread.transform_distance('20240115', '20240215')).to eq(202_402_15)
    end

    it 'adds months for relative month distance' do
      expect(IB::Spread.transform_distance('202401', '2m')).to eq('202403')
    end

    it 'adds weeks for relative week distance' do
      expect(IB::Spread.transform_distance('20240115', '1w')).to eq('20240123')
    end

    it 'raises an error for invalid distance formats' do
      expect { IB::Spread.transform_distance('202401', 'invalid') }
        .to raise_error(RuntimeError, /Wrong date/)
    end
  end

  describe '#add_leg' do
    it 'adds a contract as a leg' do
      spread = IB::Spread.new
      spread.add_leg(stock_a)
      expect(spread.legs.size).to eq(1)
      expect(spread.combo_legs.size).to eq(1)
    end

    it 'accepts action and ratio parameters' do
      spread = IB::Spread.new
      spread.add_leg(stock_a, action: :sell, ratio: 2)
      leg = spread.combo_legs.first
      expect(leg.side).to eq(:sell)
      expect(leg.ratio).to eq(2)
    end

    it 'requires an IB::Contract' do
      spread = IB::Spread.new
      expect { spread.add_leg('not a contract') }.to raise_error(RuntimeError)
    end
  end

  describe '#remove_leg' do
    it 'removes a leg by index' do
      spread = IB::Spread.new
      spread.add_leg(stock_a)
      spread.add_leg(stock_b)
      spread.remove_leg(0)
      expect(spread.legs.size).to eq(1)
      expect(spread.combo_legs.first.con_id).to eq(2)
    end

    it 'raises for an invalid index' do
      spread = IB::Spread.new
      expect { spread.remove_leg(0) }.to raise_error(RuntimeError, /Invalid leg position/)
    end
  end

  describe '#essential' do
    it 'clones legs and combo legs' do
      spread = IB::Spread.new
      spread.add_leg(stock_a)
      spread.add_leg(stock_b)
      copy = spread.essential
      expect(copy.legs.size).to eq(2)
      expect(copy.combo_legs.size).to eq(2)
      expect(copy.description).to eq(spread.description)
    end
  end

  describe '#multiplier' do
    it 'averages leg multipliers' do
      spread = IB::Spread.new
      spread.add_leg(IB::Stock.new(symbol: 'A', multiplier: 10))
      spread.add_leg(IB::Stock.new(symbol: 'B', multiplier: 20))
      expect(spread.multiplier).to eq(15)
    end
  end

  describe '#con_id' do
    it 'returns a negative sum of leg con_ids' do
      spread = IB::Spread.new
      spread.add_leg(stock_a)
      spread.add_leg(stock_b)
      expect(spread.con_id).to eq(-3)
    end
  end

  describe '#calculate_spread_value' do
    it 'sums values from portfolio values when a symbol is yielded' do
      spread = IB::Spread.new
      pvs = [
        IB::PortfolioValue.new(contract: stock_a, position: 10, market_price: 100),
        IB::PortfolioValue.new(contract: stock_b, position: 5, market_price: 200)
      ]
      result = spread.calculate_spread_value(pvs) { :position }
      expect(result).to eq(15)
    end
  end

  describe '#fake_portfolio_position' do
    it 'aggregates portfolio values into a single position' do
      spread = IB::Spread.new
      pvs = [
        IB::PortfolioValue.new(contract: stock_a, market_price: 100, market_value: 1000, unrealized_pnl: 10, average_cost: 90, realized_pnl: 5),
        IB::PortfolioValue.new(contract: stock_b, market_price: 200, market_value: 2000, unrealized_pnl: 20, average_cost: 180, realized_pnl: 15)
      ]
      result = spread.fake_portfolio_position(pvs)
      expect(result.market_price).to eq(300)
      expect(result.market_value).to eq(3000)
      expect(result.unrealized_pnl).to eq(30)
      expect(result.average_cost).to eq(270)
      expect(result.realized_pnl).to eq(20)
      expect(result.position).to eq(0)
    end
  end

  describe '#build_from_json' do
    it 'reconstructs spread from json container' do
      container = {
        'Spread' => [1, 'AAPL', 'STK', '', 0.0, '', 0.0, 'SMART', 'USD', 'AAPL', 'AAPL'],
        'legs' => [[2, 'MSFT', 'STK', '', 0.0, '', 0.0, 'SMART', 'USD', 'MSFT', 'MSFT']],
        'combo_legs' => [[1, 1, 'BUY', 'SMART']],
        'misc' => ['Test spread']
      }
      spread = IB::Spread.build_from_json(container)
      expect(spread).to be_a(IB::Spread)
      expect(spread.combo_legs.size).to eq(1)
      expect(spread.description).to eq('Test spread')
    end
  end

  describe '#as_table' do
    it 'renders a terminal table' do
      spread = IB::Spread.new
      spread.add_leg(stock_a)
      expect(spread.as_table).to be_a(String)
      expect(spread.as_table).to include('AAPL')
    end
  end

  describe '#to_human' do
    it 'returns description' do
      spread = IB::Spread.new(description: 'Calendar AAPL')
      expect(spread.to_human).to eq('Calendar AAPL')
    end
  end

  describe '#remove_leg by contract' do
    it 'removes matching leg when verified contract is provided' do
      spread = IB::Spread.new
      spread.add_leg(stock_a)
      allow(stock_a).to receive(:verify).and_return([stock_a])
      spread.remove_leg(stock_a)
      expect(spread.legs).to be_empty
    end
  end
end
