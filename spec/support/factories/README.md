# Test Factories

The IB API test suite provides convenient factory methods for creating test objects, reducing boilerplate and improving test readability.

## Overview

Factories create pre-configured IB objects with sensible defaults, allowing you to focus on the specific attributes relevant to your test.

## Available Factories

### Contract Factories

Create IB contract objects for different security types:

```ruby
# Stock factory
stock = IB::Test::Factory.create_stock
stock = IB::Test::Factory.create_stock(symbol: 'MSFT', exchange: 'NASDAQ')

# Option factory
option = IB::Test::Factory.create_option
option = IB::Test::Factory.create_option(
  symbol: 'TSLA',
  strike: 200.0,
  expiry: '20260620',
  right: 'P'
)

# Future factory
future = IB::Test::Factory.create_future
future = IB::Test::Factory.create_future(symbol: 'CL', expiry: '202512')

# Index factory
index = IB::Test::Factory.create_index
index = IB::Test::Factory.create_index(symbol: 'DJI')

# Forex factory
forex = IB::Test::Factory.create_forex
forex = IB::Test::Factory.create_forex(symbol: 'GBP')
```

### Order Factories

Create IB order objects:

```ruby
# Market order
order = IB::Test::Factory.create_market_order
order = IB::Test::Factory.create_market_order(action: 'SELL', quantity: 50)

# Limit order
order = IB::Test::Factory.create_limit_order
order = IB::Test::Factory.create_limit_order(
  action: 'BUY',
  quantity: 200,
  price: 155.50
)

# Stop order
order = IB::Test::Factory.create_stop_order(stop_price: 140.0)

# Stop-limit order
order = IB::Test::Factory.create_stop_limit_order(
  price: 150.0,
  stop_price: 140.0
)
```

### Generic Factory Method

Use the generic `create` method with a symbol:

```ruby
stock = IB::Test::Factory.create(:stock, symbol: 'GOOGL')
option = IB::Test::Factory.create(:option, symbol: 'AMZN', strike: 100.0)
order = IB::Test::Factory.create(:limit_order, price: 200.0)
```

### Factory Helper

Access factories through the helper method in specs:

```ruby
describe 'Some test' do
  it 'uses factories' do
    stock = factory.create_stock(symbol: 'NFLX')
    order = factory.create_market_order(action: 'SELL', quantity: 25)
  end
end
```

### Creating Multiple Objects

Create multiple objects at once:

```ruby
stocks = IB::Test::Factory.create_list(:stock, 3)
# Creates 3 stock objects
```

## Factory Defaults

### Stock Defaults
- symbol: 'AAPL'
- sec_type: 'STK'
- exchange: 'SMART'
- currency: 'USD'

### Option Defaults
- symbol: 'AAPL'
- sec_type: 'OPT'
- exchange: 'SMART'
- currency: 'USD'
- strike: 150.0
- expiry: '20251220'
- right: 'C'

### Future Defaults
- symbol: 'ES'
- sec_type: 'FUT'
- exchange: 'GLOBEX'
- currency: 'USD'
- expiry: '202512'

### Order Defaults
- action: 'BUY'
- quantity: 100

## File Locations

Factory files are located in:
- `spec/support/factories.rb` - Main factory module
- `spec/support/factories/base_factory.rb` - Base functionality
- `spec/support/factories/contract_factory.rb` - Contract factories
- `spec/support/factories/order_factory.rb` - Order factories
- `spec/support/factories/message_factory.rb` - Message factories
- `spec/support/factory_helper.rb` - RSpec helper

## Example Test

```ruby
require 'spec_helper'

describe 'Order placement' do
  it 'places a limit order' do
    contract = IB::Test::Factory.create_stock(symbol: 'TSLA')
    order = IB::Test::Factory.create_limit_order(
      action: 'BUY',
      quantity: 10,
      price: 250.0
    )
    
    # Test your order placement logic
    result = place_order(contract: contract, order: order)
    expect(result).to be_successful
  end
end
```

## See Also

- `spec/ib/factories_example_spec.rb` - Comprehensive examples
- Mock server documentation in `spec/support/mocks/README.md`