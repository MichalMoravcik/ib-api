require 'spec_helper'

describe IB::Connection do
  describe 'received messages management' do
    let(:ib) { IB::Connection.new }

    describe '#received' do
      it 'returns a hash' do
        expect(ib.received).to be_a(Hash)
      end

      it 'auto-creates arrays for message types' do
        array = ib.received[:NextValidId]
        expect(array).to be_an(Array)
      end

      it 'returns same array for repeated access' do
        array1 = ib.received[:NextValidId]
        array2 = ib.received[:NextValidId]
        expect(array1).to be(array2)
      end
    end

    describe '#received?' do
      it 'returns false when no messages received' do
        expect(ib.received?(:NextValidId)).to be_falsey
      end

      it 'returns true when messages received' do
        ib.received[:NextValidId] << double('message')
        expect(ib.received?(:NextValidId)).to be_truthy
      end

      it 'checks minimum count' do
        ib.received[:NextValidId] << double('message')
        expect(ib.received?(:NextValidId, 1)).to be_truthy
        expect(ib.received?(:NextValidId, 2)).to be_falsey
      end
    end

    describe '#clear_received' do
      it 'clears all messages when no args' do
        ib.received[:NextValidId] << double('message')
        ib.received[:OpenOrder] << double('message')
        ib.clear_received
        expect(ib.received[:NextValidId]).to be_empty
        expect(ib.received[:OpenOrder]).to be_empty
      end

      it 'clears specific message types' do
        ib.received[:NextValidId] << double('message')
        ib.received[:OpenOrder] << double('message')
        ib.clear_received(:NextValidId)
        expect(ib.received[:NextValidId]).to be_empty
        expect(ib.received[:OpenOrder]).not_to be_empty
      end
    end
  end

  describe '#wait_for' do
    let(:ib) { IB::Connection.new }

    it 'waits for message type' do
      allow(ib).to receive(:reader_running?).and_return(false)
      allow(ib).to receive(:process_messages)
      allow(ib).to receive(:received?).with(:NextValidId).and_return(true)

      expect { ib.wait_for(:NextValidId, 0.1) }.not_to raise_error
    end

    it 'waits for multiple messages' do
      allow(ib).to receive(:reader_running?).and_return(false)
      allow(ib).to receive(:process_messages)
      allow(ib).to receive(:received?).with(:NextValidId, 2).and_return(true)

      expect { ib.wait_for([:NextValidId, 2], 0.1) }.not_to raise_error
    end

    it 'waits for block condition' do
      allow(ib).to receive(:reader_running?).and_return(false)
      allow(ib).to receive(:process_messages)
      condition = -> { true }

      expect { ib.wait_for(0.1, &condition) }.not_to raise_error
    end

    it 'times out after specified duration' do
      allow(ib).to receive(:reader_running?).and_return(false)
      allow(ib).to receive(:process_messages)
      allow(ib).to receive(:received?).and_return(false)

      start_time = Time.now
      ib.wait_for(:NextValidId, 0.1)
      expect(Time.now - start_time).to be >= 0.1
    end
  end
end
