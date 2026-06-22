require 'main_helper'

# Edge-case tests for AbstractMessage version checking and error handling

RSpec.describe IB::Messages::Incoming::AbstractMessage do
  describe 'check_version' do
    let(:message) { IB::Messages::Incoming::NextValidId.new([]) }

    it 'passes when version matches expected integer' do
      expect { message.check_version(1, 1) }.not_to raise_error
    end

    it 'passes when version is in expected array' do
      expect { message.check_version(3, [1, 2, 3, 4]) }.not_to raise_error
    end

    it 'raises error when version does not match' do
      expect { message.check_version(1, 2) }.to raise_error(IB::Error)
    end

    it 'raises error when version not in expected array' do
      expect { message.check_version(5, [1, 2, 3]) }.to raise_error(IB::Error)
    end
  end

  describe 'valid?' do
    it 'returns true when buffer is empty' do
      msg = IB::Messages::Incoming::NextValidId.new({ version: 1 })
      expect(msg.valid?).to be true
    end

    it 'returns false when buffer has remaining data' do
      msg = IB::Messages::Incoming::NextValidId.new(['1', 'extra_data'])
      expect(msg.valid?).to be false
    end
  end

  describe 'hash initialization' do
    it 'initializes with empty buffer when given a hash' do
      msg = IB::Messages::Incoming::NextValidId.new({ version: 1, local_id: 5 })
      expect(msg.buffer).to be_an(Array)
      expect(msg.buffer).to be_empty
    end
  end

  describe 'load error handling' do
    let(:bad_msg) do
      Class.new(IB::Messages::Incoming::AbstractMessage) do
        @message_id = 9999
        @version = 1
        @data_map = [[:bad_field, :nonexistent_type]]
      end
    end

    it 'handles read errors gracefully' do
      msg = bad_msg.new(['1'])
      # Should not raise, but should set error
      expect { msg.load }.not_to raise_error
    end
  end
end
