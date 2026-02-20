# frozen_string_literal: true

require 'socket'
require 'timeout'

module IB
  module Test
    class MockServer
      DEFAULT_PORT = 7496
      DEFAULT_HOST = 'localhost'
      
      attr_reader :port, :host, :server
      
      def initialize(port: DEFAULT_PORT, host: DEFAULT_HOST)
        @port = port
        @host = host
        @server_thread = nil
        @clients = []
        @response_handlers = {}
        @latency = 0
        @error_rate = 0.0
        @force_error = false
        @running = false
      end

      # Start the server
      def start(start_timeout: 5)
        @server = TCPServer.new(host, port)
        @running = true
        @server_thread = Thread.new do
          while @running
            begin
              client_socket = @server.accept
              @clients << client_socket
              handle_client_connection(client_socket)
            rescue IOError, Errno::EBADF
              break
            end
          end
        end
        
        Timeout.timeout(start_timeout) do
          loop do
            begin
              TCPSocket.new(host, port).close
              break
            rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT
              sleep(0.1)
            end
          end
        end
      end

      # Check if server is running
      def running?
        @server_thread&.alive?
      end

      # Stop the server gracefully
      def stop(stop_timeout: 5)
        return unless @server_thread
        
        @running = false
        @server.close if @server
        @server_thread.join(stop_timeout) if @server_thread
        @server_thread.kill if @server_thread&.alive?
        @clients.each(&:close)
        @clients.clear
        @server = nil
        @server_thread = nil
      end

      # Configure response handlers
      def on_message(message_pattern, &block)
        @response_handlers[message_pattern] = block
      end

      # Add default response handlers
      def configure_default_responses
        on_message(/API\Version/) { |_, _socket| "10.8.1g" }
        on_message(/ManagedAccounts/) { |_, _socket| "U123456" }
        on_message(/ServerVersion/) { |_, _socket| "45| #{port}| US| 10.8.1g| 2" }
        on_message(/TwsConnectionTime/) { |_, _socket|
          Time.now.strftime('%Y%m%d %H:%M:%S')
        }
      end

      # Set latency for responses (in milliseconds)
      def latency=(ms)
        @latency = ms.to_f / 1000.0
      end

      # Get current latency
      def latency
        @latency * 1000.0
      end

      # Set error rate (0.0 to 1.0)
      def error_rate=(rate)
        @error_rate = [0.0, [1.0, rate.to_f].min].max
      end

      # Get current error rate
      def error_rate
        @error_rate
      end

      # Simulate error for next request
      def simulate_error
        @force_error = true
      end

      # Clear forced error state
      def clear_error
        @force_error = false
      end

      # Handle individual client connection
      def handle_client_connection(client_socket)
        Thread.new do
          begin
            buffer = ''
            while client_socket && !client_socket.closed?
              chunk = client_socket.readpartial(4096)
              buffer += chunk
              
              while (delimiter_pos = buffer.index('| 0|'))
                message = buffer[0..delimiter_pos]
                buffer = buffer[delimiter_pos + 4..-1] || ''
                message = message.chomp('| 0|')
                response = get_response(message, client_socket)
                client_socket.puts("#{response}| 0|")
              end
            end
          rescue EOFError, Errno::EPIPE, Errno::ECONNRESET
          ensure
            client_socket.close rescue nil
            @clients.delete(client_socket)
          end
        end
      end

      # Get response for a message
      def get_response(message, socket)
        if @force_error || rand <= @error_rate
          @force_error = false
          return simulate_server_error
        end
        
        sleep(@latency) if @latency > 0
        
        handler = @response_handlers.find { |pattern, _| message.match?(pattern) }
        
        if handler
          handler[1].call(message, socket).to_s
        else
          ""
        end
      end

      # Configure the server to simulate a specific scenario
      def self.for_scenario(scenario_name, port: DEFAULT_PORT)
        server = new(port: port)
        
        case scenario_name.to_sym
        when :fast_response
          server.latency = 0
          server.error_rate = 0.0
        when :slow_response
          server.latency = 200
          server.error_rate = 0.0
        when :unreliable
          server.latency = 50
          server.error_rate = 0.3
        when :version_mismatch
          server.on_message(/API\Version/) do |_, _socket|
            '!version| 10.8.1g is not supported| 504|'
          end
        when :timeout
          server.latency = 1000
        end
        
        server
      end

      private

      def simulate_server_error
        errors = [
          '!version| 10.8.1g is not supported| 504|',
          '!connection| timeout| 504|',
          '!connection| error| 504|',
          '!system| general error| 504|'
        ]
        errors.sample
      end
    end
  end
end
