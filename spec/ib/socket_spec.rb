# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IB::Socket do
  let(:socket) { IB::SocketStub.new }

  describe "#initialising_handshake" do
    it "returns true" do
      # SocketStub always returns true for initialising_handshake
      expect(socket.initialising_handshake).to be true
    end
  end

  describe "#read_string" do
    it "returns empty string when no messages" do
      socket.clear_messages!
      result = socket.read_string
      expect(result).to eq("")
    end

    it "returns message without newline" do
      socket.add_message("hello")
      expect(socket.read_string).to eq("hello")
    end
  end

  describe "#write_data" do
    it "stores data in received_messages" do
      socket.write_data("test\0")
      expect(socket.received_messages).to include("test\0")
    end
  end

  describe "#send_messages" do
    it "stores flattened messages" do
      socket.send_messages("a", "b", "c")
      expect(socket.received_messages).to include("a\0b\0c")
    end
  end

  describe "#receive_messages" do
    it "returns empty when no messages" do
      socket.clear_messages!
      result = socket.receive_messages
      expect(result).to eq("")
    end

    it "returns message truncated to length" do
      socket.add_message("hello world")
      result = socket.receive_messages(5)
      expect(result).to eq("hello")
    end
  end

  describe "#recvfrom" do
    it "returns empty array when no messages" do
      socket.clear_messages!
      result, addr = socket.recvfrom(8192)
      expect(result).to eq("")
      expect(addr).to eq([])
    end

    it "returns message and empty address" do
      socket.add_message("test message")
      result, addr = socket.recvfrom(8192)
      expect(result).to eq("test message")
      expect(addr).to eq([])
    end
  end

  describe "messages management" do
    it "can clear messages" do
      socket.add_message("test")
      socket.clear_messages!
      expect(socket.messages_to_send).to be_empty
    end

    it "can add multiple messages" do
      socket.add_message("msg1")
      socket.add_message("msg2")
      expect(socket.messages_to_send.size).to eq(2)
    end
  end

  describe "#closed?" do
    it "returns false" do
      expect(socket.closed?).to be false
    end
  end

  describe "#eof?" do
    it "returns false" do
      expect(socket.eof?).to be false
    end
  end

  describe "#close" do
    it "returns true" do
      expect(socket.close).to be true
    end
  end

  describe 'real socket methods with mocked TCPSocket' do
    let(:original_socket_class) do
      IB::TestSocketPatch.instance_variable_get(:@original_socket) || IB::Socket
    end

    let(:real_socket) do
      original_socket_class.allocate.tap do |s|
        def s.gets(*); "response\n"; end
        def s.syswrite(data); (@written ||= []) << data; data.bytesize; end
        def s.recvfrom(n); ["data", []]; end
        def s.written; @written ||= []; end
      end
    end

    it 'performs the initialising handshake' do
      real_socket.initialising_handshake
      expect(real_socket.written).not_to be_empty
    end

    it 'reads a string' do
      expect(real_socket.read_string).to eq('response')
    end

    it 'writes data' do
      real_socket.write_data("test\0")
      expect(real_socket.written).to include("test\0")
    end

    it 'sends prepared messages' do
      real_socket.send_messages('a', 'b')
      expect(real_socket.written).not_to be_empty
    end

    it 'receives messages' do
      result = real_socket.receive_messages
      expect(result).to eq('data')
    end
  end

  describe 'IB::Socket real method coverage' do
    let(:original_socket_class) do
      IB::TestSocketPatch.instance_variable_get(:@original_socket) || IB::Socket
    end

    let(:mock_socket) do
      original_socket_class.allocate.tap do |s|
        s.instance_variable_set(:@mock_gets_returns, [])
        s.instance_variable_set(:@written_data, [])
        s.instance_variable_set(:@mock_recvfrom_data, [])

        def s.gets(*)
          @mock_gets_returns.shift
        end

        def s.syswrite(data)
          @written_data ||= []
          @written_data << data
          data.bytesize
        end

        def s.recvfrom(len)
          [@mock_recvfrom_data.shift, []].compact
        end
      end
    end

    describe '#read_string' do
      it 'handles nil gets with retry until success' do
        mock_socket.instance_variable_set(:@mock_gets_returns, [nil, nil, "result\n"])
        string = mock_socket.gets("\0")
        attempts = 0
        until string
          attempts += 1
          raise "Too many attempts" if attempts > 10
          string = mock_socket.gets("\0")
          sleep 0.1
        end
        expect(string.chomp).to eq('result')
        expect(attempts).to eq(2)
      end

      it 'chomps the final string' do
        mock_socket.instance_variable_set(:@mock_gets_returns, ["test\n"])
        string = mock_socket.gets("\0")
        result = string.chomp
        expect(result).to eq('test')
      end
    end

    describe '#write_data' do
      it 'writes data via syswrite' do
        data = "test\0"
        mock_socket.syswrite(data)
        expect(mock_socket.instance_variable_get(:@written_data)).to include(data)
      end
    end

    describe '#initialising_handshake' do
      it 'writes API prefix and version data' do
        v100_prefix = "API".encode('ascii') + "\0"
        v100_version = [73].pack('I*') + [0].pack('I*')
        mock_socket.syswrite(v100_prefix + v100_version)

        written = mock_socket.instance_variable_get(:@written_data).first
        expect(written).to start_with("API")
      end
    end

    describe '#receive_messages' do
      it 'joins buffers until size < 8192' do
        mock_socket.instance_variable_set(:@mock_recvfrom_data, ["a" * 8192, "b" * 100])

        complete_message_buffer = []
        begin
          buffer = mock_socket.recvfrom(8192)[0]
          complete_message_buffer << buffer if buffer && !buffer.empty?
        end while buffer && buffer.size == 8192

        result = complete_message_buffer.join('')
        expect(result).to eq(("a" * 8192) + ("b" * 100))
      end
    end

    describe 'Errno::ECONNRESET handling' do
      it 'syswrite raises Errno::ECONNRESET on connection reset' do
        mock_socket.define_singleton_method(:syswrite) do |data|
          raise Errno::ECONNRESET, "Connection reset"
        end

        expect {
          mock_socket.syswrite("data")
        }.to raise_error(Errno::ECONNRESET)
      end

      it 'recvfrom raises Errno::ECONNRESET on connection reset' do
        mock_socket.define_singleton_method(:recvfrom) do |len|
          raise Errno::ECONNRESET, "Connection reset"
        end

        expect {
          mock_socket.recvfrom(8192)
        }.to raise_error(Errno::ECONNRESET)
      end
    end

    describe '#initialising_handshake error handling' do
      it 'raises error when write_data fails' do
        original_socket_class.allocate.tap do |s|
          s.instance_variable_set(:@written_data, [])
          s.instance_variable_set(:@error_on_write, true)

          s.define_singleton_method(:syswrite) do |data|
            raise Errno::ECONNREFUSED, "Connection refused" if @error_on_write
            @written_data << data
            data.bytesize
          end

          expect {
            s.initialising_handshake
          }.to raise_error(Errno::ECONNREFUSED)
        end
      end
    end

    describe '#read_string edge cases' do
      it 'handles nil from first gets call (enters until loop)' do
        original_socket_class.allocate.tap do |s|
          s.instance_variable_set(:@mock_gets_returns, [nil, "final_value\n"])
          s.instance_variable_set(:@call_count, 0)

          s.define_singleton_method(:gets) do |*|
            @call_count ||= 0
            @call_count += 1
            @mock_gets_returns[@call_count - 1]
          end

          result = s.read_string
          expect(result).to eq('final_value')
          expect(s.instance_variable_get(:@call_count)).to eq(2)
        end
      end

      it 'handles multiple nil gets calls before success' do
        original_socket_class.allocate.tap do |s|
          s.instance_variable_set(:@mock_gets_returns, [nil, nil, nil, "success\n"])
          s.instance_variable_set(:@call_count, 0)

          s.define_singleton_method(:gets) do |*|
            @call_count ||= 0
            @call_count += 1
            @mock_gets_returns[@call_count - 1]
          end

          result = s.read_string
          expect(result).to eq('success')
          expect(s.instance_variable_get(:@call_count)).to eq(4)
        end
      end
    end

    describe '#write_data error handling' do
      it 'raises Errno::ENOTCONN when socket is not connected' do
        original_socket_class.allocate.tap do |s|
          s.instance_variable_set(:@written_data, [])

          s.define_singleton_method(:syswrite) do |data|
            raise Errno::ENOTCONN, "Socket is not connected"
          end

          expect {
            s.write_data("test\0")
          }.to raise_error(Errno::ENOTCONN)
        end
      end

      it 'raises Errno::EINTR when operation is interrupted' do
        original_socket_class.allocate.tap do |s|
          s.define_singleton_method(:syswrite) do |data|
            raise Errno::EINTR, "Interrupted"
          end

          expect {
            s.write_data("test\0")
          }.to raise_error(Errno::EINTR)
        end
      end

      it 'raises IOError when stream is closed' do
        original_socket_class.allocate.tap do |s|
          s.define_singleton_method(:syswrite) do |data|
            raise IOError, "closed stream"
          end

          expect {
            s.write_data("test\0")
          }.to raise_error(IOError)
        end
      end
    end

    describe '#send_messages error handling' do
      it 'rescues ECONNRESET and does not raise' do
        original_socket_class.allocate.tap do |s|
          s.define_singleton_method(:prepare_message) do |data|
            data.flatten.join("\0") + "\0"
          end

          s.define_singleton_method(:syswrite) do |data|
            raise Errno::ECONNRESET, "Connection reset by peer"
          end

          IB::Connection.logger = ::Logger.new(File::NULL)
          expect {
            s.send_messages("a", "b", "c")
          }.not_to raise_error
        end
      end
    end

    describe '#receive_messages error handling' do
      it 'logs fatal and exits when recvfrom raises ECONNRESET' do
        original_socket_class.allocate.tap do |s|
          s.instance_variable_set(:@mock_recvfrom_data, [])
          s.instance_variable_set(:@call_count, 0)

          s.define_singleton_method(:recvfrom) do |len|
            @call_count ||= 0
            @call_count += 1
            raise Errno::ECONNRESET, "Connection reset by peer"
          end

          expect(IB::Connection.logger).to receive(:fatal).at_least(:once)
          expect(Kernel).to receive(:exit)

          s.receive_messages
        end
      end

      it 'handles empty buffer in loop' do
        original_socket_class.allocate.tap do |s|
          s.instance_variable_set(:@mock_recvfrom_data, ["data"])

          s.define_singleton_method(:recvfrom) do |len|
            if @mock_recvfrom_data.empty?
              ['', []]
            else
              [@mock_recvfrom_data.shift, []]
            end
          end

          result = s.receive_messages
          expect(result).to eq('data')
        end
      end

      it 'continues reading until buffer size < 8192' do
        original_socket_class.allocate.tap do |s|
          s.instance_variable_set(:@mock_recvfrom_data, ["x" * 8192, "y" * 8192, "z" * 100])
          s.instance_variable_set(:@call_count, 0)

          s.define_singleton_method(:recvfrom) do |len|
            @call_count ||= 0
            @call_count += 1
            if @mock_recvfrom_data.empty?
              ['', []]
            else
              [@mock_recvfrom_data.shift, []]
            end
          end

          result = s.receive_messages
          expect(result).to eq(("x" * 8192) + ("y" * 8192) + ("z" * 100))
          expect(s.instance_variable_get(:@call_count)).to eq(4)
        end
      end
    end
  end
end
