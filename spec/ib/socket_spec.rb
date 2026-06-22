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
end
