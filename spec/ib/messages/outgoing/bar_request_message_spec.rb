require 'spec_helper'

describe IB::Messages::Outgoing::BarRequestMessage do
  describe IB::Messages::Outgoing::RequestRealTimeBars do
    let(:contract) { factory.create_stock(symbol: 'AAPL') }

    describe '#parse' do
      it 'accepts a valid data_type symbol' do
        msg = IB::Messages::Outgoing::RequestRealTimeBars.new(
          contract: contract,
          data_type: :trades
        )
        expect { msg.encode }.not_to raise_error
      end

      it 'accepts a valid data_type string' do
        msg = IB::Messages::Outgoing::RequestRealTimeBars.new(
          contract: contract,
          data_type: 'TRADES'
        )
        expect { msg.encode }.not_to raise_error
      end

      it 'rejects an invalid data_type' do
        msg = IB::Messages::Outgoing::RequestRealTimeBars.new(
          contract: contract,
          data_type: :invalid
        )
        expect { msg.encode }.to raise_error(IB::ArgumentError)
      end

      it 'requires an IB::Contract' do
        msg = IB::Messages::Outgoing::RequestRealTimeBars.new(
          contract: 'AAPL',
          data_type: :trades
        )
        expect { msg.encode }.to raise_error(IB::ArgumentError)
      end
    end

    describe '#encode' do
      it 'encodes a realtime bars request' do
        msg = IB::Messages::Outgoing::RequestRealTimeBars.new(
          contract: contract,
          data_type: :trades,
          use_rth: 1
        )
        encoded = msg.preprocess
        expect(encoded).to include(50)
        expect(encoded).to include(3)
        expect(encoded).to include(5)
        expect(encoded).to include('TRADES')
      end
    end
  end

  describe IB::Messages::Outgoing::RequestHistoricalData do
    let(:contract) { factory.create_stock(symbol: 'AAPL') }

    describe '#parse' do
      it 'accepts a valid bar_size string' do
        msg = IB::Messages::Outgoing::RequestHistoricalData.new(
          contract: contract,
          data_type: :trades,
          bar_size: '1 min'
        )
        expect { msg.encode }.not_to raise_error
      end

      it 'rejects an invalid bar_size' do
        msg = IB::Messages::Outgoing::RequestHistoricalData.new(
          contract: contract,
          data_type: :trades,
          bar_size: 'invalid'
        )
        expect { msg.encode }.to raise_error(IB::ArgumentError)
      end
    end

    describe '#encode' do
      it 'encodes a historical data request' do
        msg = IB::Messages::Outgoing::RequestHistoricalData.new(
          contract: contract,
          data_type: :trades,
          bar_size: '1 min',
          end_date_time: '20260622 12:00:00',
          duration: '1 D',
          use_rth: 1,
          keep_up_todate: false
        )
        encoded = msg.preprocess.flatten
        expect(encoded).to include(20)
        expect(encoded).to include('1 min')
        expect(encoded).to include('1 D')
        expect(encoded).to include('TRADES')
      end
    end
  end
end
