require 'spec_helper'

describe IB::RawMessageParser do
  let(:mock_socket) { instance_double(TCPSocket) }
  let(:parser) { IB::RawMessageParser.new(mock_socket) }

  def build_message(fields)
    body = fields.join("\0") + "\0"
    [body.bytesize].pack('N') + body
  end

  describe '#each' do
    it 'yields parsed messages' do
      data = build_message(['3', '1', 'AAPL'])
      allow(mock_socket).to receive(:recvfrom).with(4096).and_return([data], [''])

      messages = []
      parser.each { |msg| messages << msg }
      expect(messages).to eq([['3', '1', 'AAPL']])
    end

    it 'handles multiple messages in one buffer' do
      msg1 = build_message(['3', '1'])
      msg2 = build_message(['9', '2'])
      allow(mock_socket).to receive(:recvfrom).with(4096).and_return([msg1 + msg2], [''])

      messages = []
      parser.each { |msg| messages << msg }
      expect(messages).to eq([['3', '1'], ['9', '2']])
    end

    it 'processes data accumulated across multiple reads' do
      data = build_message(['3', '1'])
      allow(mock_socket).to receive(:recvfrom).with(4096).and_return([data[0..3]], [data[4..-1]], [''])

      messages = []
      parser.each { |msg| messages << msg }
      expect(messages).to be_empty

      parser.each { |msg| messages << msg }
      expect(messages).to eq([['3', '1']])
    end

    it 'stops when socket returns empty' do
      allow(mock_socket).to receive(:recvfrom).with(4096).and_return([''])
      expect { |b| parser.each(&b) }.not_to yield_control
    end
  end

  describe '#valid_data?' do
    it 'returns false when buffer is too short' do
      parser.instance_variable_set(:@data, 'abc')
      expect(parser.valid_data?).to be false
    end

    it 'returns false when length exceeds data size' do
      parser.instance_variable_set(:@data, [10].pack('N') + 'short')
      expect(parser.valid_data?).to be false
    end
  end

  describe '#next_msg_length' do
    it 'reads length from first 4 bytes' do
      parser.instance_variable_set(:@data, [42].pack('N'))
      expect(parser.next_msg_length).to eq(42)
    end
  end

  describe '#parse_message' do
    it 'splits null-terminated fields' do
      raw = "hello\0world\0"
      result = parser.parse_message(raw, raw.bytesize)
      expect(result).to eq(['hello', 'world'])
    end
  end

  describe '#validate_message_footer' do
    it 'raises when last byte is not null' do
      expect { parser.validate_message_footer('data', 4) }.to raise_error(/invalid last byte/)
    end
  end
end
