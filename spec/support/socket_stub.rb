# frozen_string_literal: true

require 'socket'

# Minimal SocketStub implementation for testing
class IB::SocketStub
  attr_accessor :messages_to_send, :received_messages

  def initialize
    @messages_to_send = []
    @received_messages = []
  end

  def open(*_args)
    self
  end

  def close
    true
  end

  def closed?
    false
  end

  def eof?
    false
  end

  def initialising_handshake
    true
  end

  # Support for select system call
  def self.select(read_ary, *_args)
    return [[], [], [], []] if read_ary.nil? || read_ary.empty?
    return [[], [], [], []] unless read_ary.any? { |s| s.is_a?(IB::SocketStub) }

    stub_socket = read_ary.find { |s| s.is_a?(IB::SocketStub) }
    return [[], [], [], []] if stub_socket.messages_to_send.empty?

    # Add a default message if no messages are available
    stub_socket.add_message("!:\n1\n") if stub_socket.messages_to_send.empty?

    [[stub_socket]] + Array.new(3, [])
  end

  def read_string
    if messages_to_send.empty?
      sleep 0.01
      ''
    else
      message = messages_to_send.shift
      message.to_s.chomp
    end
  end

  def write_data(data)
    @received_messages << data
    true
  end

  def syswrite(data)
    @received_messages << data
    true
  end

  def send_messages(*data)
    @received_messages << data.flatten.join("\0")
    true
  end

  def receive_messages(len = 8192)
    if messages_to_send.empty?
      sleep 0.01
      ''
    else
      message = messages_to_send.shift
      message.to_s[0..len - 1]
    end
  end

  def recvfrom(len)
    if messages_to_send.empty?
      sleep 0.01
      ['', []]
    else
      message = messages_to_send.shift
      [message.to_s[0..len - 1], []]
    end
  end

  def recvmsg(len, _flags = 0)
    if messages_to_send.empty?
      sleep 0.01
      ['', []]
    else
      message = messages_to_send.shift
      [message.to_s[0..len - 1], []]
    end
  end

  def clear_messages!
    @messages_to_send.clear
  end

  def add_message(message)
    messages_to_send << message
  end
end
