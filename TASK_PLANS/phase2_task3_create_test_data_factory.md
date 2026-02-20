# Task Plan: Create Test Data Factory

## Task Description
Build `spec/support/factories.rb` for generating test models, including contract factories (stocks, options, futures), order factories for different order types, and message factories for incoming/outgoing messages.

## Objectives
1. Create reusable factory patterns for test data generation
2. Support all contract types (stocks, options, futures, etc.)
3. Implement order factories for various order types
4. Create message factories for IB protocol messages
5. Ensure factories are easily configurable and extensible

## Prerequisites
- Understanding of IB contract properties and order types
- Familiarity with Factory Bot or custom factory patterns
- Knowledge of IB TWS message protocol

## Implementation Steps

### Step 1: Create Factories Main File
```bash
cat > spec/support/factories.rb << 'EOF'
module IB
  module Test
    class Factory
      attr_reader :attributes, :type
      
      def initialize(type = nil)
        @type = type
        @attributes = {}
      end
      
      def configure(&block)
        instance_eval(&block)
        self
      end
      
      def build
        raise NotImplementedError, "Subclasses must implement #build"
      end
      
      def create
        build
      end
      
      # Define attributes using methodMissing or explicit methods
      def method_missing(name, value = nil)
        if value.nil? && !block_given?
          super
        else
          @attributes[name] = value || yield if block_given?
          self
        end
      end
      
      def respond_to_missing?(name, include_private = false)
        true
      end
    end
  end
end
EOF
```

### Step 2: Create Contract Factories
```bash
cat >> spec/support/factories.rb << 'EOF'
module IB
  module Test
    class StockFactory < Factory
      def initialize
        super(:stock)
        @attributes = {
          symbol: 'AAPL',
          sec_type: 'STK',
          exchange: 'SMART',
          currency: 'USD'
        }
      end
      
      def build
        IB::Stock.new(@attributes)
      end
    end
    
    class OptionFactory < Factory
      def initialize
        super(:option)
        @attributes = {
          symbol: 'AAPL',
          sec_type: 'OPT',
          exchange: 'SMART',
          currency: 'USD',
          last_trade_date_or_contract_month: Time.now.strftime('%Y%m%d'),
          strike: 150.0,
          right: 'C',
          multiplier: '100'
        }
      end
      
      def build
        IB::Option.new(@attributes)
      end
    end
    
    class FutureFactory < Factory
      def initialize
        super(:future)
        @attributes = {
          symbol: 'ES',
          sec_type: 'FUT',
          exchange: 'GLOBEX',
          currency: 'USD',
          last_trade_date_or_contract_month: Time.now.strftime('%Y%m%d'),
          multiplier: '50'
        }
      end
      
      def build
        IB::Future.new(@attributes)
      end
    end
    
    class ContractFactory < Factory
      def initialize(type = :stock)
        super(:contract)
        @type = type
      end
      
      def build
        case @type.to_sym
        when :stock
          StockFactory.new.configure { |f| f.attributes.each { |k, v| send(k, v) } }.build
        when :option
          OptionFactory.new.configure { |f| f.attributes.each { |k, v| send(k, v) } }.build
        when :future
          FutureFactory.new.configure { |f| f.attributes.each { |k, v| send(k, v) } }.build
        else
          raise "Unknown contract type: #{@type}"
        end
      end
    end
  end
end
EOF
```

### Step 3: Create Order Factories
```bash
cat >> spec/support/factories.rb << 'EOF'
module IB
  module Test
    class OrderFactory < Factory
      def initialize(type = :market)
        super(:order)
        @type = type
      end
      
      def build
        order = IB::Order.new(@attributes)
        # Configure order type based on @type
        case @type.to_sym
        when :limit
          order.lmt_price = 150.0
        when :stop
          order.aux_price = 145.0
        when :stop_limit
          order.lmt_price = 147.5
          order.aux_price = 145.0
        when :trailing_stop
          order.trailing_percent = 2.5
        end
        order.order_type = @type.to_s.upcase
        order
      end
    end
  end
end
EOF
```

### Step 4: Create Message Factories
```bash
cat >> spec/support/factories.rb << 'EOF'
module IB
  module Test
    class MessageFactory < Factory
      def initialize(type = :contract_data)
        super(:message)
        @type = type
      end
      
      def build
        case @type.to_sym
        when :contract_data
          build_contract_data_message
        when :order_status
          build_order_status_message
        when :execution_data
          build_execution_data_message
        when :account_value
          build_account_value_message
        else
          raise "Unknown message type: #{@type}"
        end
      end
      
      private
      
      def build_contract_data_message
        contract = @attributes[:contract] || IB::Test::Factory.stock.build
        format_ib_message(
          contract.symbol, 
          contract.sec_type,
          contract.exchange, 
          contract.currency
        )
      end
      
      def build_order_status_message
        order_id = @attributes[:order_id] || 1
        filled = @attributes[:filled] || 0
        remaining = @attributes[:remaining] || 100
        status = @attributes[:status] || 'PendingSubmit'
        
        format_ib_message(
          order_id,
          @attributes[:contract]&.symbol || 'AAPL',
          status,
          filled,
          remaining
        )
      end
    end
  end
end
EOF
```

### Step 5: Add Factory Convenience Methods
```bash
cat >> spec/support/factories.rb << 'EOF'
module IB
  module Test
    class Factory
      # Class methods for easy access
      def self.stock(*args, &block)
        factory = StockFactory.new
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
      
      def self.option(*args, &block)
        factory = OptionFactory.new
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
      
      def self.future(*args, &block)
        factory = FutureFactory.new
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
      
      def self.contract(type = :stock, *args, &block)
        factory = ContractFactory.new(type)
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
      
      def self.market_order(*args, &block)
        factory = OrderFactory.new(:market)
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
      
      def self.limit_order(*args, &block)
        factory = OrderFactory.new(:limit)
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
      
      def self.stop_order(*args, &block)
        factory = OrderFactory.new(:stop)
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
      
      def self.message(type = :contract_data, *args, &block)
        factory = MessageFactory.new(type)
        factory.configure(&block) if block
        args.each { |attr| factory.send(*attr.split('=')) } if args.any?
        factory
      end
    end
  end
end
EOF
```

### Step 6: Update Spec Helper to Load Factories
Add to `spec/spec_helper.rb`:
```ruby
# Load test factories
dir = File.expand_path('spec/support', __dir__)
load File.join(dir, 'factories.rb')

# Include factories in RSpec
RSpec.configure do |config|
  config.include IB::Test, type: :factory
end
```

### Step 7: Create Example Test Using Factories
```bash
cat > spec/ib/factories_spec.rb << 'EOF'
require 'spec_helper'

describe "Test Data Factories" do
  describe IB::Test::StockFactory do
    it "should create a default stock contract" do
      factory = IB::Test::Factory.stock
      contract = factory.build
      
      expect(contract).to be_a(IB::Stock)
      expect(contract.symbol).to eq('AAPL')
      expect(contract.sec_type).to eq('STK')
    end
    
    it "should allow customization" do
      factory = IB::Test::Factory.stock.configure do
        symbol 'MSFT'
        exchange 'NASDAQ'
      end
      
      contract = factory.build
      expect(contract.symbol).to eq('MSFT')
      expect(contract.exchange).to eq('NASDAQ')
    end
  end
  
  describe IB::Test::OptionFactory do
    it "should create an option contract" do
      factory = IB::Test::Factory.option
      contract = factory.build
      
      expect(contract).to be_a(IB::Option)
      expect(contract.sec_type).to eq('OPT')
      expect(contract.right).to eq('C')
    end
  end
  
  describe IB::Test::OrderFactory do
    it "should create different order types" do
      market_order = IB::Test::Factory.market_order.build
      expect(market_order.order_type).to eq('MARKET')
      
      limit_order = IB::Test::Factory.limit_order.build
      expect(limit_order.order_type).to eq('LIMIT')
      expect(limit_order.lmt_price).to eq(150.0)
    end
  end
end
EOF
```

### Step 8: Create Integration Test Example
```bash
cat > spec/ib/factories_integration_spec.rb << 'EOF'
require 'spec_helper'

describe "Factory integration" do
  it "should create and use contracts in tests" do
    # Create stock contract using factory
    aapl = IB::Test::Factory.stock(symbol: 'AAPL').build
    
    # Verify it's a valid contract
    expect(aapl).to be_valid
    expect(aapl.symbol).to eq('AAPL')
  end
  
  it "should create orders with contracts" do
    contract = IB::Test::Factory.stock(symbol: 'MSFT').build
    order = IB::Test::Factory.limit_order(action: 'BUY', lmt_price: 200.5).build
    
    expect(order.action).to eq('BUY')
  end
end
EOF
```

### Step 9: Create Documentation for Factories
Create `spec/support/factories/README.md`:
```markdown
# Test Data Factories

## Overview

Factories provide an easy way to create test data for the IB API gem. They support contracts, orders, and messages with sensible defaults that can be customized.

## Usage

### Basic Factory Usage

```ruby
describe "Stock contract" do
  let(:contract) { IB::Test::Factory.stock.build }
  
  it "should be valid" do
    expect(contract).to be_valid
  end
end
```

### Customizing Attributes

#### Method 1: Block Configuration
```ruby
factory = IB::Test::Factory.stock.configure do
  symbol 'GOOGL'
  exchange 'NASDAQ'
end
contract = factory.build
```

#### Method 2: Direct Attribute Setting
```ruby
factory = IB::Test::Factory.stock(symbol: 'GOOGL', exchange: 'NASDAQ')
contract = factory.build
```

#### Method 3: Chaining
```ruby
factory = IB::Test::Factory.stock.symbol('GOOGL').exchange('NASDAQ')
contract = factory.build
```

## Available Factories

### Contract Factories

#### Stock Factory
```ruby
aapl = IB::Test::Factory.stock.build  # Default: AAPL stock
googl = IB::Test::Factory.stock(symbol: 'GOOGL').build
```

#### Option Factory
```ruby
call_option = IB::Test::Factory.option.build  # Default: AAPL call option
put_option = IB::Test::Factory.option(right: 'P').build  # Put option
```

#### Future Factory
```ruby
future = IB::Test::Factory.future.build  # Default: ES future
es_future = IB::Test::Factory.future(symbol: 'ES').build
```

#### Generic Contract Factory
```ruby
stock = IB::Test::Factory.contract(:stock).build
option = IB::Test::Factory.contract(:option).build
future = IB::Test::Factory.contract(:future).build
```

### Order Factories

#### Market Order
```ruby
market_order = IB::Test::Factory.market_order.build
expected { market_order.order_type }.to eq('MARKET')
```

#### Limit Order
```ruby
limit_order = IB::Test::Factory.limit_order.build
expected { limit_order.order_type }.to eq('LIMIT')
```

#### Stop Order
```ruby
stop_order = IB::Test::Factory.stop_order.build
expected { stop_order.order_type }.to eq('STP')
```

#### Stop Limit Order
```ruby
stop_limit = IB::Test::Factory.order(:stop_limit).build
expected { stop_limit.order_type }.to eq('STP LMT')
```

#### Trailing Stop Order
```ruby
trailing_stop = IB::Test::Factory.order(:trailing_stop).build
expected { trailing_stop.order_type }.to eq('TRAIL')
```

### Message Factories

#### Contract Data Message
```ruby
contract = IB::Test::Factory.stock.build
message = IB::Test::Factory.message(:contract_data, contract: contract).build
```

#### Order Status Message
```ruby
message = IB::Test::Factory.message(:order_status,
  order_id: 123,
  status: 'Filled',
  filled: 100,
  remaining: 0
).build
```

## Factory Inheritance

All factories inherit from `IB::Test::Factory` and support the same interface:

```ruby
factory = IB::Test::Factory.stock
# Get the underlying attributes
expected { factory.attributes }.to include(symbol: 'AAPL')

# Build creates and returns the object
contract = factory.build

# Create is an alias for build
another_contract = factory.create
```

## Best Practices

1. **Use factories for test data**: Reduces boilerplate code in tests
2. **Customize when needed**: Override default values for specific test cases
3. **Reuse factories**: Keep common configurations in factory definitions
4. **Test factory output**: Verify created objects meet expectations
5. **Use appropriate types**: Choose the right factory for the scenario

## Examples

### Testing Contract Validation
```ruby
describe IB::Stock do
  it "validates required fields" do
    valid_contract = IB::Test::Factory.stock.build
    expect(valid_contract).to be_valid
    
    invalid_contract = IB::Test::Factory.stock(symbol: nil).build
    expect(invalid_contract).not_to be_valid
  end
end
```

### Testing Order Creation
```ruby
describe IB::Order do
  it "creates different order types" do
    market_order = IB::Test::Factory.market_order.build
expected { market_order.order_type }.to eq('MARKET')
    
    limit_order = IB::Test::Factory.limit_order(lmt_price: 250).build
expected { limit_order.lmt_price }.to eq(250)
  end
end
```

### Testing Message Parsing
```ruby
describe IB::Messages::Incoming::ContractData do
  it "parses contract data messages" do
    message = IB::Test::Factory.message(:contract_data).build
    parsed = IB::Messages::Incoming::ContractData.parse(message)
    expect(parsed).to be_a(IB::Contract)
  end
end
```

## Advanced Usage

### Extending Factories
Create custom factories by inheriting from base classes:

```ruby
class MyStockFactory < IB::Test::StockFactory
  def initialize
    super
    # Override defaults
    @attributes[:symbol] = 'CUSTOM'
  end
end
```

### Multiple Configurations
Use different configurations for the same factory:

```ruby
default_stock = IB::Test::Factory.stock
nasdaq_stock = IB::Test::Factory.stock(exchange: 'NASDAQ')
nyse_stock = IB::Test::Factory.stock(exchange: 'NYSE')
```

### Sharing Factories Between Tests
Define shared factories in test support files:

```ruby
# spec/support/custom_factories.rb
module CustomFactories
  def self.my_contract
    IB::Test::Factory.stock(symbol: 'CUSTOM').build
  end
end
```

## Factory Directory Structure

```bash
spec/support/
├── factories.rb          # Main factory definitions
└── factories/            # Additional factory files (if needed)
    ├── contracts.rb      # Contract-specific factories
    ├── orders.rb         # Order-specific factories
    └── messages.rb       # Message factories
```

## Troubleshooting

### Factory Not Creating Expected Object
- Verify the factory type matches the expected class
- Check attribute values using `factory.attributes`

### Attributes Not Applied
- Ensure you're calling `.build` or `.create`, not just accessing the factory
- Check for typos in attribute names

### Missing Factory Type
- Verify the factory exists and is properly loaded
- Check spelling of factory names

## Integration with RSpec

Factories are automatically included in RSpec tests:

```ruby
RSpec.configure do |config|
  config.include IB::Test, type: :factory
end
```

This allows using factories directly in tests without explicit setup.
