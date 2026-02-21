require 'spec_helper'

describe IB::Connection do
  describe 'message subscription system' do
    let(:ib) { IB::Connection.new }

    describe '#subscribe' do
      it 'subscribes with symbol message type' do
        subscriber = proc { |msg| msg }
        id = ib.subscribe(:NextValidId, &subscriber)
        expect(id).to be_a(Integer)
        expect(id).to be > 0
      end

      it 'subscribes with class message type' do
        subscriber = proc { |msg| msg }
        id = ib.subscribe(IB::Messages::Incoming::NextValidId, &subscriber)
        expect(id).to be_a(Integer)
      end

      it 'subscribes with regexp pattern' do
        subscriber = proc { |msg| msg }
        id = ib.subscribe(/NextValid/, &subscriber)
        expect(id).to be_a(Integer)
      end

      it 'subscribes to multiple message types' do
        subscriber = proc { |msg| msg }
        id = ib.subscribe(:NextValidId, :OpenOrder, &subscriber)
        expect(id).to be_a(Integer)
      end

      it 'raises error without subscriber' do
        expect { ib.subscribe(:NextValidId) }.to raise_error(IB::ArgumentError)
      end

      it 'raises error with invalid message type' do
        subscriber = proc { |msg| msg }
        expect { ib.subscribe(:InvalidMessage, &subscriber) }.to raise_error(IB::Error)
      end

      it 'raises error with non-callable subscriber' do
        expect { ib.subscribe(:NextValidId, 'not a proc') }.to raise_error(IB::ArgumentError)
      end
    end

    describe '#unsubscribe' do
      it 'unsubscribes single id' do
        subscriber = proc { |msg| msg }
        id = ib.subscribe(:NextValidId, &subscriber)
        result = ib.unsubscribe(id)
        expect(result).to be_an(Array)
      end

      it 'unsubscribes multiple ids' do
        subscriber = proc { |msg| msg }
        id1 = ib.subscribe(:NextValidId, &subscriber)
        id2 = ib.subscribe(:OpenOrder, &subscriber)
        result = ib.unsubscribe(id1, id2)
        expect(result).to be_an(Array)
      end

      it 'logs error for non-existent subscriber id' do
        expect(ib.logger).to receive(:error)
        ib.unsubscribe(999_999)
      end
    end
  end
end
