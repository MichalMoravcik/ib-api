# Task Plan: Decouple from Real IB Connection

## Task Description
Create mock TWS server implementation using Rack/Rails metal, implement wire protocol mocks for common message types, and set up VCR-like cassette recording for integration scenarios.

## Objectives
1. Build mock TWS server that simulates IB protocol
2. Implement configurable responses for common message types
3. Add cassette recording/playback capability
4. Ensure tests can run without real IB connection

## Prerequisites
- Ruby and Bundler installed
- Basic understanding of IB TWS protocol (socket-based, message-delimited)
- Knowledge of Rack middleware

## Implementation Steps

### Step 1: Create Mock Server Structure
```bash
mkdir -p spec/support/mocks
cat > spec/support/mocks/mock_server.rb << 'EOF'
module IB
  module Test
    class MockServer
      def initialize(port: 7496, host: 'localhost')
        @port = port
        @host = host
        @server_thread = nil
      end
      
      def start
        # Implementation will use Rack::Handler::WEBrick
      end
      
      def stop
        # Stop server gracefully
      end
    end
  end
end
EOF
```

### Step 2: Implement Rack-Based Mock Server
Add to `spec/support/mocks/mock_server.rb`:
```ruby
def start
  require 'rack'
  require 'webrick'
  
  app = Rack::Builder.new do
    use Rack::CommonLogger
    run MockServerHandler.new
  end
  
  @server = WEBrick::HTTPServer.new(
    Port: @port,
    Logger: WEBrick::Log.new('/dev/null'),
    AccessLog: []
  )
  @server.mount('/', app)
  
  @server_thread = Thread.new do
    @server.start
  end
  
  # Wait for server to start
  sleep(0.5)
end
```

### Step 3: Create Mock Server Handler
```bash
cat > spec/support/mocks/server_handler.rb << 'EOF'
require 'rack'

class MockServerHandler
  def initialize(app = nil)
    @app = app
  end
  
  def call(env)
    request = Rack::Request.new(env)
    
    # Parse IB protocol messages (delimited by \| 0\|)
    body = request.body.read
    
    # Route to appropriate handler based on message type
    if body.start_with?('API\\Version')
      [200, {}, ["10.8.1g\\| 0\\|"]]
    elsif body.start_with?('ManagedAccounts')
      [200, {}, ["U123456\\| 0\\|"]]
    else
      [200, {}, ["\\| 0\\|"]]
    end
  end
end
EOF
```

### Step 4: Implement Response Registry
Add to `spec/support/mocks/mock_server.rb`:
```ruby
class MockServer
  def configure_responses(responses = {})
    @responses = responses
  end
  
  def default_responses
    {
      'API\\Version' => "10.8.1g\\| 0\\|",
      'ManagedAccounts' => "U123456\\| 0\\|",
      'ServerVersion' => "45\\| 7496\\| US\\| 10.8.1g\\| 2\\| 0\\|",
      'TwsConnectionTime' => Time.now.strftime("%Y%m%d\\: %H:%M:%S") + "\\| 0\\|"
    }
  end
end
```

### Step 5: Add Cassette Recording Support
```bash
cat > spec/support/mocks/cassette.rb << 'EOF'
module IB
  module Test
    class Cassette
      def initialize(name)
        @name = name
        @recorded = false
        @file_path = "spec/fixtures/cassettes/#{name}.yaml"
      end
      
      def load
        return {} unless File.exist?(@file_path)
        YAML.load_file(@file_path) || {}
      end
      
      def record(request, response)
        cassette = load
        cassette[@request_key] ||= []
        cassette[@request_key] << { request: request, response: response }
        File.write(@file_path, cassette.to_yaml)
      end
    private
      def request_key
        Digest::SHA2.hexdigest(request)
      end
    end
  end
end
EOF
```

### Step 6: Update Spec Helper
Add to `spec/spec_helper.rb`:
```ruby
dir = File.expand_path('spec/support/mocks', __dir__)
Dir.glob("#{dir}/*.rb").each { |f| require f }
```

### Step 7: Create Example Test Using Mock Server
```bash
cat > spec/ib/mocks_spec.rb << 'EOF'
require 'spec_helper'

describe "Mock TWS Server" do
  Given(:mock_server) { IB::Test::MockServer.new(port: 7496) }
  
  describe "connection simulation" do
    it "should accept connections" do
      mock_server.start
      socket = TCPSocket.new('localhost', 7496)
      mock_server.stop
    end
  end
  
  describe "protocol responses" do
    it "should respond to version request" do
      mock_server.start
      socket = TCPSocket.new('localhost', 7496)
      socket.puts "API\\Version\\| 0\\|"
      
      response = socket.gets
      expect(response).to include("10.8.1g")
      
      socket.close
      mock_server.stop
    end
  end
end
EOF
```

### Step 8: Test Mock Server
```bash
bundle exec rspec spec/ib/mocks_spec.rb --format documentation
```

### Step 9: Document Usage
Create `spec/support/README.md`:
```markdown
# Mock TWS Server

## Usage

### Basic Usage
```ruby
given(:mock_server) { IB::Test::MockServer.new }
and { mock_server.start }
when  { connection.connect(host: 'localhost', port: 7496) }
then  { connection.connected? }.should be_true
and   { mock_server.stop }
```

### Custom Responses
```ruby
given(:mock_server) do
  server = IB::Test::MockServer.new
  server.configure_responses(
    'ManagedAccounts' => "U123456, U789012\\| 0\\|"
  )
end
```

### Cassette Recording
1. First run with recording:
   ```bash
   RECORD_CASSETTE=true bundle exec rspec spec/...
   ```

2. Subsequent runs use recorded responses:
   ```bash
   USE_CASSETTE=true bundle exec rspec spec/...
   ```
```

## Success Criteria
- ✅ Mock TWS server accepts socket connections on port 7496
- ✅ Server responds to basic IB protocol messages
- ✅ Response configuration system working
- ✅ Cassette recording/playback functional
- ✅ Example tests passing using mock server

## Time Estimate: 8-12 hours
