# frozen_string_literal: true

require_relative 'socket_stub'
require_relative '../support/message_builder'

# Patch IB::Socket to use SocketStub in test environment
module IB
  module TestSocketPatch
    def self.apply!
      # Save the original Socket class
      @original_socket = IB::Socket if IB.const_defined?(:Socket)

      # Define or replace Socket with our stub
      IB.const_set(:Socket, SocketStub) unless IB.const_defined?(:Socket)

      # Monkey patch the open method to return our stub directly
      return if IB::Socket.instance_methods.include?(:open)

      IB::Socket.define_method(:open) do |*_args|
        SocketStub.new
      end

      # Override Kernel.select to use our socket stub's select method
      Kernel.module_eval do
        alias_method :original_select, :select

        define_method(:select) do |*args|
          # Check if any of the arguments contain our socket stub
          if args[0] && args[0].any? { |s| s.is_a?(IB::SocketStub) }
            IB::SocketStub.select(*args)
          else
            original_select(*args)
          end
        end
      end
    end
  end
end
