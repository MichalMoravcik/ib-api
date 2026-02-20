# Task Plan: Enhance Test Helpers

## Task Description  
Add helper for mocking socket responses, create time-freezing utilities for timestamp tests, and add BigDecimal comparison helpers.

## Objectives  
1. Create specialized helper for mocking socket responses in tests  
2. Implement time-freezing utilities to handle timestamp tests consistently  
3. Add BigDecimal comparison helpers for financial calculations  
4. Integrate helpers with existing test infrastructure  
5. Document helper usage and best practices

## Prerequisites  
- Familiarity with RSpec testing patterns  
- Understanding of Time/Date manipulation in tests  
- Knowledge of BigDecimal operations and precision handling

## Implementation Steps

### Step 1: Create Socket Mocking Helper
```bash
cat > spec/support/helpers/socket.rb << 'EOF'
module IB
  module Test
    module SocketHelpers
      extend RSpec::SharedContext
      
      let(:mock_socket) { IB::Test::MockSocket.new }
      
      def stub_socket_connection(host, port)
        allow(IB::Socket).to receive(:new).with(host, port) { mock_socket }
      end
      
      def with_socket_responses(responses)
        mock_socket.configure_responses(responses)
        yield
      ensure
        mock_socket.reset!
      end
      
      def expect_socket_to_receive(message)
        expect(mock_socket.received_messages).to eventually(include(message))
      end
      
      def expect_socket_to_send(message)
        expect(mock_socket.sent_messages).to eventually(include(message))
      end
    end
  end
end
EOF
```

### Step 2: Create Time Freezing Helper
```bash
cat > spec/support/helpers/time.rb << 'EOF'
module IB
  module Test
    module TimeHelpers
      extend RSpec::SharedContext
      
      let(:frozen_time) { Time.parse('2023-01-01 12:00:00 UTC') }
      
      def freeze_time(time = frozen_time)
        allow(Time).to receive(:now) { time }
        allow(Time).to receive(:strftime) do |format|
          time.strftime(format)
        end
      end
      
      def travel_to(time_string)
        time = Time.parse(time_string)
        freeze_time(time)
      end
      
      def unfreeze_time
        allow(Time).to receive(:now).and_call_original
        allow(Time).to receive(:strftime).and_call_original
      end
    end
  end
end
EOF
```

### Step 3: Create BigDecimal Helper
```bash
cat > spec/support/helpers/bigdecimal.rb << 'EOF'
module IB
  module Test
    module BigDecimalHelpers
      extend RSpec::SharedContext
      
      def expect_bigdecimal(value, expected)
        expect(value.to_s).to eq(expected.to_s)
      end
      
      def be_within_tolerance(tolerance = 0.01)
        matcher = RSpec::Matchers::BuiltIn::BeWithin.new(tolerance)
        RSpec::Matchers.define(:be_within_tolerance) do |expected|
          match { |actual| (BigDecimal(actual.to_s) - BigDecimal(expected.to_s)).abs <= tolerance }
          diffable
        end
      end
      
      def expect_price_to_be(expected)
        matcher = RSpec::Matchers.define do |expected_value|
          match { |actual| (BigDecimal(actual.to_s) - BigDecimal(expected_value.to_s)).abs < 0.01 }
          failure_message { |actual| "expected #{actual} to be approximately #{expected_value}" }
        end
      end
    end
  end
end
EOF
```

### Step 4: Create Matchers Helper
```bash
cat > spec/support/helpers/matchers.rb << 'EOF'
module IB
  module Test
    module Matchers
      extend RSpec::Matchers
      
      def have_ib_message_type(type)
        matcher = Matchers::HaveIBMessageType.new(type)
      end
      
      def be_valid_contract
        matcher = Matchers::BeValidContract.new
      end
    end
  
  module Test
    module Matchers
      class HaveIBMessageType < RSpec::Matchers::BuiltIn::Include
        def initialize(type)
          @type = type.to_s
        end
        
        def description
          "have IB message type #{@type}"
        end
      end
      
      class BeValidContract < RSpec::Matchers::BuiltIn::BeTrue
        def description
          "be a valid IB contract"
        end
      end
    end
  end
end
EOF
```

### Step 5: Update Spec Helper to Load Helpers
Add to `spec/spec_helper.rb`:
```ruby
# Load test helpers
dir = File.expand_path('spec/support/helpers', __dir__)
Dir.glob("#{dir}/*.rb").each { |f| require f }

# Configure RSpec to include helpers
RSpec.configure do |config|
  config.include IB::Test::SocketHelpers, type: :socket
  config.include IB::Test::TimeHelpers, type: :time
  config.include IB::Test::BigDecimalHelpers, type: :bigdecimal
  config.include IB::Test::Matchers
end
```

### Step 6: Create Example Test Using Socket Helper
```bash
cat > spec/ib/helpers/socket_helper_spec.rb << 'EOF'
require 'spec_helper'

describe "Socket Helpers", :socket do
  include_context "with mock socket"
  
  describe "#stub_socket_connection" do
    it "should replace real socket with mock" do
      stub_socket_connection('localhost', 7496)
      socket = IB::Socket.new('localhost', 7496)
      expect(socket).to be_a(IB::Test::MockSocket)
    end
  end
  
  describe "#with_socket_responses" do
    it "should configure mock responses" do
      with_socket_responses('API\\Version' => '10.8.1g') do
        mock_socket.puts('API\\Version')
        response = mock_socket.gets
        expect(response).to include('10.8.1g')
      end
    end
  end
end
EOF
```

### Step 7: Create Example Test Using Time Helper
```bash
cat > spec/ib/helpers/time_helper_spec.rb << 'EOF'
require 'spec_helper'

describe "Time Helpers", :time do
  include_context "with frozen time"
  
  describe "#freeze_time" do
    it "should make Time.now return frozen time" do
      freeze_time(frozen_time)
      expect(Time.now).to eq(frozen_time)
    end
  end
  
  describe "#travel_to" do
    it "should travel to specified time" do
      travel_to('2023-12-31 23:59:59 UTC')
      expected_time = Time.parse('2023-12-31 23:59:59 UTC')
      expect(Time.now).to eq(expected_time)
    end
  end
end
EOF
```

### Step 8: Create Example Test Using BigDecimal Helper
```bash
cat > spec/ib/helpers/bigdecimal_helper_spec.rb << 'EOF'
require 'spec_helper'

describe "BigDecimal Helpers", :bigdecimal do
  describe "#expect_bigdecimal" do
    it "should compare BigDecimal values correctly" do
      value = BigDecimal('100.5')
      expect_bigdecimal(value, '100.5')
    end
  end
  
  describe "#expect_price_to_be" do
    it "should allow small differences in price comparison" do
      value = BigDecimal('100.50')
      expect_price_to_be(value, '100.505').to be_truthy
    end
  end
end
EOF
```

### Step 9: Create Example Test Using Matchers
```bash
cat > spec/ib/helpers/matchers_helper_spec.rb << 'EOF'
require 'spec_helper'

describe "Custom Matchers" do
  describe "#be_valid_contract" do
    it "should check if contract is valid" do
      stock = IB::Stock.new(symbol: 'AAPL')
      expect(stock).to be_valid_contract
    end
  end
end
EOF
```

### Step 10: Create Documentation for Helpers
Create `spec/support/README.md`:
```markdown
# Test Helpers

## Overview
Test helpers provide reusable utilities for common testing scenarios. They reduce boilerplate and ensure consistent test patterns.

## Available Helpers

### Socket Helpers (`spec/support/helpers/socket.rb`)

Utilities for testing socket communications:

```ruby
describe "Socket communication" do
  include_context "with mock socket"
  
  it "should send messages" do
    stub_socket_connection('localhost', 7496)
    
    socket = IB::Socket.new('localhost', 7496)
    expect(socket).to be_a(IB::Test::MockSocket)
  end
end
```

#### Using with_socket_responses

```ruby
describe "Configured responses" do
  it "should respond with configured messages" do
    with_socket_responses('API\\Version' => '10.8.1g') do
      mock_socket.puts('API\\Version')
      response = mock_socket.gets
      expect(response).to include('10.8.1g')
    end
  end
end
```

### Time Helpers (`spec/support/helpers/time.rb`)

Utilities for freezing time in tests:

```ruby
describe "Time-dependent code" do
  include_context "with frozen time"
  
  it "should use consistent timestamps" do
    freeze_time(Time.parse('2023-01-01'))
    
    timestamp = Time.now
    expect(timestamp).to eq(Time.parse('2023-01-01'))
  end
end
```

#### Traveling to specific times

```ruby
describe "Time travel" do
  it "should handle different time zones" do
    travel_to('2023-12-31 23:59:59 UTC')
    
    expect(Time.now).to eq(Time.parse('2023-12-31 23:59:59 UTC'))
    
    travel_to('2024-01-01 00:00:00 EST')
    # Now in a different time zone
  end
end
```

### BigDecimal Helpers (`spec/support/helpers/bigdecimal.rb`)

Utilities for comparing financial values:

```ruby
describe "Price comparisons" do
  include_context "with bigdecimal helpers"
  
  it "should handle precision correctly" do
    price = BigDecimal('100.5')
    expected { expect_bigdecimal(price, '100.5') }
  end
end
```

#### Tolerance-based comparisons

```ruby
describe "Price tolerance" do
  it "should allow small differences" do
    price = BigDecimal('100.5')
    expected { expect_price_to_be(price, '100.501') }.to be_truthy
    expected { expect_price_to_be(price, '100.6') }.to be_falsey
  end
end
```

### Custom Matchers (`spec/support/helpers/matchers.rb`)

Custom RSpec matchers for IB-specific testing:

```ruby
describe "IB Contract" do
  it "should be valid contract" do
    stock = IB::Stock.new(symbol: 'AAPL')
    expect(stock).to be_valid_contract
  end
end
```

## Helper Directory Structure

```bash
spec/support/helpers/
├── socket.rb        # Socket communication helpers
├── time.rb          # Time freezing utilities
├── bigdecimal.rb    # BigDecimal comparison helpers
└── matchers.rb      # Custom RSpec matchers
```

## Using Helpers in Tests

### Basic Usage

```ruby
describe "Feature" do
  include IB::Test::SocketHelpers
  include IB::Test::TimeHelpers
  
  # Use helper methods
end
```

### Using Shared Contexts

```ruby
describe "With helpers" do
  include_context "with mock socket"
  include_context "with frozen time"
  
  # Helpers automatically available
end
```

### Integration with Factories

```ruby
describe "Factory with helpers" do
  include IB::Test::TimeHelpers
  
  it "should create objects with frozen time" do
    freeze_time(Time.parse('2023-01-01'))
    
    contract = IB::Test::Factory.stock.build
    # Contract created with frozen timestamp
  end
end
```

## Best Practices

### Socket Testing
- Use mock sockets for unit tests
- Configure responses specific to each test case
- Reset socket state between tests
- Verify both sent and received messages

### Time Testing
- Freeze time for deterministic tests
- Unfreeze after each test to avoid side effects
- Use UTC for consistency across environments
- Document expected time zone behavior

### BigDecimal Testing
- Use string literals for precision
- Set appropriate tolerances for financial comparisons
- Document precision requirements in test descriptions
- Consider currency-specific rounding rules

### Matcher Testing
- Create matchers for domain-specific concepts
- Ensure matchers provide clear failure messages
- Test matchers with both positive and negative cases
- Document matcher behavior in the matcher definition

## Advanced Usage

### Combining Multiple Helpers

```ruby
describe "Complex scenario" do
  include IB::Test::SocketHelpers
  include IB::Test::TimeHelpers
  
  it "should handle socket communication with timeouts" do
    freeze_time(Time.parse('2023-01-01'))
    stub_socket_connection('localhost', 7496)
    
    # Test complex interaction
  end
end
```

### Creating Custom Helpers
Create new helper files in `spec/support/helpers/`:

```ruby
# spec/support/helpers/custom.rb
module IB
  module Test
    module CustomHelpers
      def custom_helper_method
        # Implementation
      end
    end
  end
end
```

Then include in `spec_helper.rb`:

```ruby
# Load custom helpers
dir = File.expand_path('spec/support/helpers', __dir__)
Dir.glob("#{dir}/*.rb").each { |f| require f }

RSpec.configure do |config|
  config.include IB::Test::CustomHelpers, type: :custom
end
```

## Troubleshooting

### Helpers Not Available
- Verify helper is included in the spec
- Check that it's loaded by `spec_helper.rb`
- Ensure proper namespace (`IB::Test`)

### Time Not Freezing
- Verify `freeze_time` is called before the code under test
- Check that unfreeze isn't being called prematurely
- Ensure no other code is resetting Time methods

### BigDecimal Comparisons Failing
- Check precision of expected values
- Adjust tolerance if needed
- Verify string literals are being used for BigDecimal creation

### Socket Helpers Not Working
- Verify mock socket is properly stubbed
- Check that responses are configured correctly
- Ensure socket state is reset between tests

## Examples

See `spec/ib/helpers/` for comprehensive examples:
- `socket_helper_spec.rb`: Socket helper usage
- `time_helper_spec.rb`: Time freezing examples
- `bigdecimal_helper_spec.rb`: BigDecimal comparisons
- `matchers_helper_spec.rb`: Custom matcher tests
