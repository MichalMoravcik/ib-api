require 'spec_helper'

describe IB::Messages::Incoming::TickByTick do
  describe 'instantiated with a data hash' do
    let(:base_data) do
      {
        ticker_id: 1,
        tick_type: 0,
        time: Time.now
      }
    end

    describe 'tick type 0' do
      subject { IB::Messages::Incoming::TickByTick.new(base_data) }

      it 'is a TickByTick message' do
        expect(subject).to be_an(IB::Messages::Incoming::TickByTick)
      end

      it 'has an empty to_human' do
        expect(subject.to_human).to include('TickByTick')
      end
    end

    describe 'tick type 1 (Last)' do
      subject do
        IB::Messages::Incoming::TickByTick.new(
          base_data.merge(
            tick_type: 1,
            price: 150.25,
            size: 100,
            mask: 0,
            exchange: 'SMART',
            special_conditions: ''
          )
        )
      end

      it 'reports last trade data' do
        expect(subject.to_human).to include('Last')
        expect(subject.to_human).to include('150.25')
        expect(subject.to_human).to include('100')
        expect(subject.to_human).to include('SMART')
      end

      it 'exposes accessors' do
        expect(subject.price).to eq(150.25)
        expect(subject.size).to eq(100)
        expect(subject.exchange).to eq('SMART')
      end

      it 'exposes mask accessor' do
        expect(subject.mask).to eq(0)
      end
    end

    describe 'tick type 2 (AllLast)' do
      let(:buffer) do
        [
          '1', '2', Time.now.to_i.to_s,
          '150.25', '100', '3', 'SMART', ''
        ]
      end
      subject { IB::Messages::Incoming::TickByTick.new(buffer) }

      it 'resolves the mask' do
        expect(subject.resolve_mask).to eq([1, 2])
      end

      it 'includes labels from the mask' do
        expect(subject.to_human).to include('PastLimit')
        expect(subject.to_human).to include('Unreported')
      end

      it 'exposes mask accessor' do
        expect(subject.mask).to eq(3)
      end
    end

    describe 'tick type 3 (Bid/Ask)' do
      subject do
        IB::Messages::Incoming::TickByTick.new(
          base_data.merge(
            tick_type: 3,
            bid_price: 150.20,
            ask_price: 150.30,
            bid_size: 50,
            ask_size: 75,
            mask: 0
          )
        )
      end

      it 'reports bid/ask data' do
        expect(subject.to_human).to include('Bid/Ask')
        expect(subject.to_human).to include('150.2')
        expect(subject.to_human).to include('150.3')
      end

      it 'exposes bid and ask accessors' do
        expect(subject.bid_price).to eq(150.20)
        expect(subject.ask_price).to eq(150.30)
        expect(subject.bid_size).to eq(50)
        expect(subject.ask_size).to eq(75)
      end
    end

    describe 'tick type 4 (Midpoint)' do
      subject do
        IB::Messages::Incoming::TickByTick.new(
          base_data.merge(
            tick_type: 4,
            mid_point: 150.25
          )
        )
      end

      it 'reports midpoint data' do
        expect(subject.to_human).to include('Midpoint')
        expect(subject.to_human).to include('150.25')
      end

      it 'exposes the mid_point accessor' do
        expect(subject.mid_point).to eq(150.25)
      end
    end
  end
end
