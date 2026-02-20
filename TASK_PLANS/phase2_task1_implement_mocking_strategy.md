# Task Plan: Implement Comprehensive Mocking Strategy

## Task Description
Create `spec/support/mocks/` directory and build mock implementations for IB::Socket (network communication), IB message parsers, and connection state manager.

## Objectives
1. Create mocking infrastructure for external dependencies
2. Implement IB::Socket mock that simulates network communication
3. Mock message parsers for testing parsing logic in isolation
4. Create connection state manager mocks
5. Ensure mocks are configurable and reusable across tests

## Prerequisites
- Basic understanding of IB TWS protocol (socket-based, message-delimited)
- Familiarity with RSpec mocking techniques
- Knowledge of Ruby's socket and IO classes

## Implementation Steps

### Step 1: Create Mocks Directory Structure
```bash
mkdir -p spec/support/mocks
cat > spec/support/mocks/.gitkeep << 'EOF'
# Directory for test mocks
EOF
```

### Step 2: Create Socket Mock
```bash
cat > spec/support/mocks/socket.rb << 'EOF'
module IB
  module Test
    class MockSocket
      attr_reader :received_messages, :sent_messages
      
      def initialize(host: nil, port: nil)
        @host = host
        @port = port
        @received_messages = []
        @sent_messages = []
        @buffer = ''
        @disconnected = false
      end
      
      # Socket interface methods
      def connect(host = @host, port = @port)
        @connected = true
        true
      end
      
      def close
        @disconnected = true
      end
      
      def closed?
        @disconnected
      end
      
      def puts(message)
        sent_messages << message
        @buffer += "#{message}\\| 0\\|\\n"
      end
      
      def gets(maxlen = nil)
        return nil if @buffer.empty?
        
        # Find message delimiter
        delimiter_pos = @buffer.index("\\| 0\\|\\n")
        if delimiter_pos
          message = @buffer[0..delimiter_pos + 5]
          @buffer = @buffer[delimiter_pos + 6..-1] || ''
          received_messages << message
          message
        else
          nil
        end
      end
      
      def eof?
        @buffer.empty? && closed?
      end
      
      def readpartial(maxlen)
        # Simplified version for basic testing
        @buffer || ''
      end
      
      def connected?
        @connected && !closed?
      end
      
      def reset!
        @received_messages.clear
        @sent_messages.clear
        @buffer = ''
      end
      
      # Configure responses for testing
      def configure_responses(responses)
        @responses = responses
      end
      
      def respond_to_message(message_key, &block)
        @response_handlers ||= {}
        @response_handlers[message_key] = block
      end
    end
  end
end
```

### Step 3: Create Message Parser Mock
```bash
cat > spec/support/mocks/message_parser.rb << 'EOF'
module IB
  module Test
    class MockMessageParser
      attr_reader :parsed_messages
      
      def initialize
        @parsed_messages = []
        @response_map = {}
      end
      
      def parse(message)
        parsed_messages << message
        
        # Find matching response
        if @response_map.key?(message)
          return @response_map[message]
        end
        
        # Default responses for common messages
        case message
        when /API\\Version/
          '10.8.1g'
        when /ManagedAccounts/
          'U123456'
        when /ServerVersion/
          '45| 7496| US| 10.8.1g| 2'
        when /TwsConnectionTime/
          Time.now.strftime('%Y%m%d %H:%M:%S')
        else
          ''
        end
      end
      
      def configure_response(message_pattern, response)
        @response_map[message_pattern] = response
      end
      
      def clear!
        @parsed_messages.clear
        @response_map.clear
      end
    end
  end
end
```

### Step 4: Create Connection State Manager Mock
```bash
cat > spec/support/mocks/connection_manager.rb << 'EOF'
module IB
  module Test
    class MockConnectionManager
      attr_reader :connection_state, :last_message
      
      def initialize
        @connection_state = :disconnected
        @last_message = nil
        @message_queue = []
      end
      
      def connect(host, port)
        @connection_state = :connecting
        sleep(0.1)  # Simulate connection delay
        @connection_state = :connected
        true
      end
      
      def disconnect
        @connection_state = :disconnected
        true
      end
      
      def connected?
        @connection_state == :connected
      end
      
      def send_message(message)
        @last_message = message
        @message_queue << message
      end
      
      def receive_message
        return nil if @message_queue.empty?
        @message_queue.shift
      end
      
      def clear_messages!
        @message_queue.clear
      end
      
      def simulate_disconnection
        @connection_state = :disconnected
        raise IB::DisconnectError, 'Simulated disconnection'
      end
      
      def simulate_timeout
        sleep(0.5)
        raise Timeout::Error, 'Simulated timeout'
      end
    end
  end
end
```

### Step 5: Create Factory for Mock Objects
```bash
cat > spec/support/mocks/factory.rb << 'EOF'
module IB
  module Test
    class MockFactory
      def self.socket(*args)
        new.socket(*args)
      end
      
      def self.parser
        new.parser
      end
      
      def self.connection_manager
        new.connection_manager
      end
      
      # Instance methods for chaining
      def initialize
        @mocks = {}
      end
      
      def socket(*args)
        @mocks[:socket] ||= MockSocket.new(*args)
      end
      
      def parser
        @mocks[:parser] ||= MockMessageParser.new
      end
      
      def connection_manager
        @mocks[:connection_manager] ||= MockConnectionManager.new
      end
      
      def all
        @mocks.values
      end
      
      def clear!
        @mocks.each_value(&:clear!)
        @mocks.clear
      end
    end
  end
end
```

### Step 6: Create RSpec Helpers for Mocks
```bash
cat > spec/support/mocks/rspec_helpers.rb << 'EOF'
RSpec.extend IB::Test

RSpec.shared_context "with mock socket" do
  let(:mock_socket) { IB::Test::MockSocket.new }
  
  before do
    allow(IB::Socket).to receive(:new).and_return(mock_socket)
  end
  
  after do
    mock_socket.reset!
  end
end

RSpec.shared_context "with mock parser" do
  let(:mock_parser) { IB::Test::MockMessageParser.new }
  
  before do
    allow_any_instance_of(IB::RawMessageParser).to receive(:parse).and_wrap_original do |method, message|
      mock_parser.parse(message)
    end
  end
  
  after do
    mock_parser.clear!
  end
end

RSpec.shared_context "with mock connection" do
  let(:mock_connection) { IB::Test::MockConnectionManager.new }
  
  before do
    allow(IB::Connection).to receive(:new) { |*args| 
      mock_connection
    }
  end
end

# Convenience methods
module IB::Test
  def self.with_mock_socket(&block)
    mock = MockSocket.new
    allow(IB::Socket).to receive(:new).and_return(mock)
    block.call(mock)
  ensure
    mock.reset!
  end
  
  def self.with_mock_parser(&block)
    mock = MockMessageParser.new
    allow_any_instance_of(IB::RawMessageParser).to receive(:parse) do |message|
      mock.parse(message)
    end
    block.call(mock)
  ensure
    mock.clear!
  end
end
EOF
```

### Step 7: Update Spec Helper to Load Mocks
Add to `spec/spec_helper.rb`:
```ruby
# Load test mocks
dir = File.expand_path('spec/support/mocks', __dir__)
Dir.glob("#{dir}/*.rb").each { |f| require f }

# Configure RSpec to use mocks when appropriate
RSpec.configure do |config|
  config.include IB::Test::RSpecHelpers, type: :mock
  
  # Use mocks for certain test types
  config.before(:each, type: :unit) do
    # Auto-configure mocks for unit tests
  end
end
```

### Step 8: Create Example Test Using Mocks
```bash
cat > spec/ib/mocks/unit/socket_mock_spec.rb << 'EOF'
require 'spec_helper'

describe IB::Test::MockSocket do
  subject { described_class.new }
  
  describe "#connect" do
    it "should return true when connecting" do
      expect(subject.connect('localhost', 7496)).to be true
    end
    
    it "should track connection state" do
      subject.connect('localhost', 7496)
      expect(subject).to be_connected
    end
  end
  
  describe "message handling" do
    it "should buffer outgoing messages with delimiter" do
      subject.puts("API\\Version")
      expect(subject.sent_messages).to include("API\\Version")
    end
    
    it "should parse incoming messages by delimiter" do
      subject.puts("API\\Version")
      message = subject.gets
      expect(message).to eq("API\\Version\\| 0\\|\\n")
    end
    
    it "should track received messages" do
      subject.puts("API\\Version")
      subject.gets
      expect(subject.received_messages).to include("API\\Version\\| 0\\|\\n")
    end
  end
  
  describe "reset functionality" do
    it "should clear message buffers on reset" do
      subject.puts("test")
      subject.received_messages << "received"
      subject.reset!
      
      expect(subject.sent_messages).to be_empty
      expect(subject.received_messages).to be_empty
    end
  end
end
EOF
```

### Step 9: Create Example Test for Parser Mock
```bash
cat > spec/ib/mocks/unit/parser_mock_spec.rb << 'EOF'
require 'spec_helper'

describe IB::Test::MockMessageParser do
  subject { described_class.new }
  
  describe "#parse" do
    it "should track parsed messages" do
      subject.parse("API\\Version")
      expect(subject.parsed_messages).to include("API\\Version")
    end
    
    it "should return default response for common messages" do
      expect(subject.parse("API\\Version")).to eq("10.8.1g")
      expect(subject.parse("ManagedAccounts")).to eq("U123456")
    end
  end
  
  describe "custom responses" do
    it "should allow configuration of custom responses" do
      subject.configure_response("CustomMessage", "CustomResponse")
      expect(subject.parse("CustomMessage")).to eq("CustomResponse")
    end
  end
end
EOF
```

### Step 10: Create Example Test for Connection Manager Mock
```bash
cat > spec/ib/mocks/unit/connection_manager_mock_spec.rb << 'EOF'
require 'spec_helper'

describe IB::Test::MockConnectionManager do
  subject { described_class.new }
  
  describe "connection lifecycle" do
    it "should transition through connection states" do
      expect(subject).to be_disconnected
      subject.connect('localhost', 7496)
      expect(subject).to be_connected
      subject.disconnect
      expect(subject).to be_disconnected
    end
  end
  
  describe "message queue" do
    it "should queue outgoing messages" do
      subject.send_message("TestMessage")
      expect(subject.receive_message).to eq("TestMessage")
    end
    
    it "should clear message queue" do
      subject.send_message("TestMessage")
      subject.clear_messages!
      expect(subject.receive_message).to be_nil
    end
  end
end
EOF
```

### Step 11: Create Documentation for Mocks
Create `spec/support/mocks/README.md`:
```markdown
# Test Mocks for IB API

## Overview

This directory contains mock implementations of external dependencies to enable isolated unit testing without requiring a real IB TWS/Gateway connection.

## Mock Implementations

### 1. MockSocket

Simulates socket communication with message buffering and tracking.

**Usage**:
```ruby
describe "Socket communication" do
  include_context "with mock socket"
  
  it "should send messages" do
    mock_socket.puts("API\\Version")
    expect(mock_socket.sent_messages).to include("API\\Version")
  end
end
```

### 2. MockMessageParser

Mocks the message parsing logic for testing parsers in isolation.

**Usage**:
```ruby
describe "Message parsing" do
  include_context "with mock parser"
  
  it "should parse version message" do
    response = mock_parser.parse("API\\Version")
    expect(response).to eq("10.8.1g")
  end
end
```

### 3. MockConnectionManager

Simulates connection state and message queue management.

**Usage**:
```ruby
describe "Connection lifecycle" do
  include_context "with mock connection"
  
  it "should manage connection state" do
    expect(mock_connection).to be_disconnected
    mock_connection.connect('localhost', 7496)
    expect(mock_connection).to be_connected
  end
end
```

### 4. MockFactory

Convenience factory for creating mock objects.

**Usage**:
```ruby
socket = IB::Test::MockFactory.socket
parser = IB::Test::MockFactory.parser
manager = IB::Test::MockFactory.connection_manager
```

## RSpec Helpers

Shared contexts for easy mock integration:

```ruby
# Use in your specs
describe "Some functionality" do
  include_context "with mock socket"
  include_context "with mock parser"
  include_context "with mock connection"
  
  # Tests can now use mock_socket, mock_parser, mock_connection
end
```

## Configuring Mock Behavior

### Socket Responses

```ruby
describe "Custom socket responses" do
  it "should respond to custom messages" do
    mock_socket.respond_to_message("API\\Version") do |message|
      "10.9.0g"  # Custom response
    end
    
    mock_socket.puts("API\\Version")
    response = mock_socket.gets
    # Response will be "10.9.0g\\| 0\\|"
  end
end
```

### Parser Responses

```ruby
describe "Custom parser responses" do
  it "should return custom responses" do
    mock_parser.configure_response("CustomMessage", "ExpectedResponse")
    
    response = mock_parser.parse("CustomMessage")
    expect(response).to eq("ExpectedResponse")
  end
end
```

## Testing Error Conditions

### Simulating Disconnections

```ruby
describe "Disconnection handling" do
  include_context "with mock connection"
  
  it "should handle disconnections" do
    mock_connection.connect('localhost', 7496)
    mock_connection.simulate_disconnection
    
    expect { some_operation }.to raise_error(IB::DisconnectError)
  end
end
```

### Simulating Timeouts

```ruby
describe "Timeout handling" do
  include_context "with mock connection"
  
  it "should handle timeouts" do
    expect {
      mock_connection.simulate_timeout
    }.to raise_error(Timeout::Error)
  end
end
```

## Best Practices

1. **Clear mock state** between tests to avoid test pollution
2. **Configure responses** specific to each test scenario
3. **Verify mock interactions** using `sent_messages` and `received_messages`
4. **Use shared contexts** for consistent mock setup
5. **Combine with factories** for quick test object creation

## Integration with Real Tests

Mocks can be gradually integrated into existing tests:

```ruby
describe "Real functionality with mocks" do
  before do
    # Replace real socket with mock
    allow(IB::Socket).to receive(:new).and_return(mock_socket)
  end
  
  # Now tests can run without real connection
end
```

## Migration Path

To migrate existing tests to use mocks:

1. Identify tests that require IB connection
2. Replace `IB::Socket.new` with mock socket stub
3. Configure appropriate responses for test scenarios
4. Verify test behavior matches real connection expectations
5. Gradually increase mock coverage
```

### Step 12: Run Tests to Verify Mocks Work
```bash
bundle exec rspec spec/ib/mocks/
```

### Step 13: Document Mock Usage Patterns
Add to `TESTING.md`:
```markdown
## Using Test Mocks

### Overview
Test mocks allow running unit tests without a real IB TWS/Gateway connection.

### Available Mocks

- **MockSocket**: Simulates socket communication
- **MockMessageParser**: Tests message parsing logic
- **MockConnectionManager**: Manages connection state

### Usage Examples

#### Basic Mock Usage
```ruby
describe "Socket tests" do
  let(:mock_socket) { IB::Test::MockSocket.new }
  
  it "should send messages" do
    mock_socket.puts("API\\Version")
    expect(mock_socket.sent_messages).to include("API\\Version")
  end
end
```

#### Shared Contexts (Recommended)
```ruby
describe "Integration test" do
  include_context "with mock socket"
  include_context "with mock parser"
  
  it "should work without real connection" do
    # Test logic here
  end
end
```

#### Factory Pattern
```ruby
socket = IB::Test::MockFactory.socket
parser = IB::Test::MockFactory.parser
```

### Configuring Mock Behavior

#### Custom Responses
```ruby
mock_socket.respond_to_message("API\\Version") do |message|
  "10.9.0g"
end
```

#### Default Responses
Mocks provide sensible defaults:
- `"API\\Version"` → `"10.8.1g"`
- `"ManagedAccounts"` → `"U123456"`
- `"ServerVersion"` → `"45| 7496| US| 10.8.1g| 2"`

### Mock Directory Structure
```bash
spec/support/mocks/
├── socket.rb          # Socket communication mock
├── message_parser.rb  # Message parsing mock
├── connection_manager.rb # Connection state mock
├── factory.rb         # Mock object factory
├── rspec_helpers.rb   # RSpec integration
└── README.md          # Mock documentation
```

### When to Use Mocks vs Real Connection

**Use mocks for:**
- Unit tests (fast, isolated)
- CI/CD pipelines
- Testing error conditions
- Contract testing

**Use real connection for:**
- Integration tests (optional)
- End-to-end workflows
- Protocol compliance testing
```

## Success Criteria
- ✅ MockSocket implementation complete with message buffering
- ✅ MockMessageParser implementation with configurable responses
- ✅ MockConnectionManager implementation with state tracking
- ✅ RSpec helpers for easy mock integration
- ✅ Factory pattern for creating mock objects
- ✅ Example tests passing using mocks
- ✅ Documentation complete with usage examples
- ✅ Mocks properly integrated into spec_helper.rb

## Time Estimate: 10-15 hours
