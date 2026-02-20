# Mock TWS Server

## Overview

The mock TWS server provides a local simulation of the Interactive Brokers TWS/Gateway server, allowing tests to run without requiring a real IB connection.

## Basic Usage

### Starting and Stopping the Server

```ruby
describe "Server lifecycle" do
  Given(:mock_server) { IB::Test::MockServer.new(port: 7496) }
  
  it "should start and accept connections" do
    mock_server.start
    expect(mock_server).to be_running
    
    # Test connection
    socket = TCPSocket.new('localhost', 7496)
    expect(socket).to be_a(TCPSocket)
    socket.close
    
    mock_server.stop
  end
end
```

### Default Responses

The server comes with default handlers for common IB protocol messages:

```ruby
mock_server.start

# API Version
socket = TCPSocket.new('localhost', 7496)
socket.puts "API\\Version\| 0\|"
response = socket.gets
expect(response).to include("10.8.1g")

# Managed Accounts
socket.puts "ManagedAccounts\| 0\|"
response = socket.gets
expect(response).to include("U123456")

socket.close
mock_server.stop
```

## Configuration

### Custom Response Handlers

```ruby
describe "Custom responses" do
  Given(:mock_server) do
    server = IB::Test::MockServer.new
    server.on_message(/CustomMessage/) do |message, socket|
      "CustomResponse"
    end
    server
  end
  
  it "should respond with custom message" do
    mock_server.start
    socket = TCPSocket.new('localhost', 7496)
    socket.puts "CustomMessage\| 0\|"
    
    response = socket.gets
    expect(response).to include("CustomResponse")
    
    socket.close
    mock_server.stop
  end
end
```

### Scenario Presets

```ruby
# Fast response server (no latency, no errors)
fast_server = IB::Test::MockServer.for_scenario(:fast_response)

# Slow response server (200ms latency)
slow_server = IB::Test::MockServer.for_scenario(:slow_response)

# Unreliable server (50ms latency, 30% error rate)
unreliable_server = IB::Test::MockServer.for_scenario(:unreliable)

# Version mismatch scenario
version_server = IB::Test::MockServer.for_scenario(:version_mismatch)

# Timeout scenario (1000ms latency)
timeout_server = IB::Test::MockServer.for_scenario(:timeout)
```

## Advanced Features

### Latency Simulation

```ruby
Given(:mock_server) do
  server = IB::Test::MockServer.new
  server.latency = 100  # 100ms latency
  server
end
```

### Error Injection

```ruby
Given(:mock_server) do
  server = IB::Test::MockServer.new
  server.error_rate = 0.2  # 20% error rate
  server
end

# Force specific error
mock_server.simulate_error
```

### Response Builders

The server includes response builders for common IB message types:

```ruby
# Contract data response
contract_response = mock_server.build_contract_data(1, {
  symbol: 'AAPL',
  sec_type: 'STK',
  exchange: 'SMART',
  currency: 'USD'
})

# Order status response
order_response = mock_server.build_order_status(123, 'Filled', 100, 0)

# Market data response  
market_response = mock_server.build_market_data(1, 1, '150.25', 100)
```

## Server Extensions

### Full IB Simulation

```ruby
Given(:mock_server) do
  server = IB::Test::MockServer.new
  server.configure_full_simulation('U123456')
  server
end

# This configures:
# - Default TWS responses
# - Contract data support
# - Market data support
# - Order placement support
# - Account data support
# - Reasonable latency and error rate
```

### Specific Features

```ruby
# Configure TWS version
mock_server.configure_tws_version('10.9.0g')

# Support contract data
mock_server.support_contract_data

# Support market data
mock_server.support_market_data

# Support order placement
mock_server.support_order_placement

# Support account data
mock_server.support_account_data('U123456')
```

## Integration with Existing Tests

### Using with Connection

```ruby
describe "Integration with IB connection" do
  Given(:mock_server) { IB::Test::MockServer.new }
  Given(:connection) { IB::Connection.new(host: 'localhost', port: 7496) }
  
  before do
    mock_server.start
  end
  
  after do
    mock_server.stop
  end
  
  it "should connect to mock server" do
    expect(connection.connect).to be_truthy
    expect(connection.connected?).to be_truthy
  end
end
```

### Using with Socket Stub

```ruby
describe "Socket stub integration" do
  Given(:mock_server) { IB::Test::MockServer.new }
  Given(:socket_stub) { IB::SocketStub.new }
  
  before do
    mock_server.start
    # Configure socket stub to connect to mock server
  end
  
  it "should work with existing socket stub infrastructure" do
    # Test interaction between socket stub and mock server
  end
end
```

## Best Practices

1. **Start/Stop in Before/After Hooks**: Always start the server in `before` and stop in `after` hooks
2. **Use Appropriate Scenarios**: Choose scenario presets that match your test requirements
3. **Configure Specific Responses**: Add custom handlers for specific test cases
4. **Clean Up**: Ensure servers are properly stopped to avoid port conflicts
5. **Use Different Ports**: For parallel testing, use different ports for different test suites

## Directory Structure

```bash
spec/support/mocks/
├── server.rb                # Main server implementation
├── server_handler.rb        # Request handler
├── server_utils.rb          # Utility methods
├── server_extensions.rb     # Additional features
└── response_builders.rb     # Response builders
```

## Environment Variables

```bash
# Use mock server instead of real connection
USE_MOCK_SERVER=true bundle exec rspec

# Use specific port
MOCK_SERVER_PORT=7497 bundle exec rspec
```

## Troubleshooting

### Port Already in Use
- Ensure servers are properly stopped in after hooks
- Use different ports for parallel test runs
- Check for zombie processes using the port

### Connection Refused
- Verify server is started before tests run
- Check server port configuration
- Ensure firewall allows local connections

### Unexpected Responses
- Verify response handlers are configured correctly
- Check message format and delimiters
- Use logging to debug message processing

## Examples

See `spec/ib/mocks/server_spec.rb` for comprehensive examples of mock server usage.