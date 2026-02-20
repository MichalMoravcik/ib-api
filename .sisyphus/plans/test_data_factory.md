# Test Data Factory Implementation Plan

## Objective
Create a comprehensive test data factory to eliminate test boilerplate and improve test maintainability for the IB API Ruby gem.

## Current State
- Mock server is functional (8/8 tests passing)
- No factory pattern exists for creating test objects
- Tests currently use manual object instantiation
- No standardized way to create contracts, orders, or messages

## Tasks

### Task 1: Create Factory Infrastructure
**Description**: Set up the factory module structure and base classes
**Files to create**:
- `spec/support/factories.rb` - Main factory module
- `spec/support/factories/base_factory.rb` - Base factory class
- `spec/support/factories/contract_factory.rb` - Contract factories
- `spec/support/factories/order_factory.rb` - Order factories
- `spec/support/factories/message_factory.rb` - Message factories

**Expected outcomes**:
- Factory module loads without errors
- Base factory provides common methods
- All factory files are required in spec_helper

### Task 2: Implement Contract Factories
**Description**: Create factories for all IB contract types
**Contract types to support**:
- Stock (IB::Stock)
- Option (IB::Option)
- Future (IB::Future)
- Index (IB::Index)
- CFD (IB::CFD)
- Commodity (IB::Commodity)
- Bond (IB::Bond)
- Combo (IB::Bag)
- Forex (IB::Forex)
- FutureOption (IB::FutureOption)
- Spread (IB::Spread)
- StockSpread (IB::StockSpread)

**Factory methods**:
- `create_stock(symbol:, **attrs)`
- `create_option(symbol:, strike:, expiry:, right:, **attrs)`
- `create_future(symbol:, expiry:, **attrs)`
- etc.

**Example usage**:
```ruby
# Stock factory
stock = IB::Test::Factory.create_stock(symbol: 'AAPL')
stock = IB::Test::Factory.stock(symbol: 'AAPL', exchange: 'NASDAQ')

# Option factory
option = IB::Test::Factory.create_option(
  symbol: 'AAPL',
  strike: 150.0,
  expiry: '20251220',
  right: 'C',
  exchange: 'SMART'
)
```

### Task 3: Implement Order Factories
**Description**: Create factories for all IB order types
**Order types to support**:
- Market order (IB::Order with order_type: 'MKT')
- Limit order (IB::Order with order_type: 'LMT')
- Stop order (IB::Order with order_type: 'STP')
- StopLimit order (IB::Order with order_type: 'STP LMT')
- TrailingStop order
- TrailingStopLimit order
- PeggedToStock order
- PeggedToPrimary order
- Relative order
- Volatility order

**Factory methods**:
- `create_market_order(action:, quantity:, **attrs)`
- `create_limit_order(action:, quantity:, price:, **attrs)`
- `create_stop_order(action:, quantity:, stop_price:, **attrs)`
- `create_stop_limit_order(action:, quantity:, price:, stop_price:, **attrs)`
- etc.

**Example usage**:
```ruby
# Market order
order = IB::Test::Factory.create_market_order(action: 'BUY', quantity: 100)

# Limit order with overrides
order = IB::Test::Factory.create_limit_order(
  action: 'BUY',
  quantity: 100,
  price: 150.25,
  tif: 'GTC'
)
```

### Task 4: Implement Message Factories
**Description**: Create factories for IB protocol messages
**Message types to support**:
- OpenOrder
- ContractData
- ContractDataEnd
- OrderStatus
- ExecutionData
- AccountValue
- PortfolioValue
- Position
- MarketData
- TickPrice
- TickSize
- Error
- ConnectionStatus

**Factory methods**:
- `create_open_message(order_id:, contract:, order:, **attrs)`
- `create_contract_data(contract_id:, contract_details:, **attrs)`
- `create_order_status(order_id:, status:, **attrs)`
- `create_execution_data(exec_id:, order_id:, **attrs)`
- etc.

**Example usage**:
```ruby
# OpenOrder message
msg = IB::Test::Factory.create_open_order(
  order_id: 123,
  contract: factory.stock(symbol: 'AAPL'),
  order: factory.limit_order(action: 'BUY', quantity: 100, price: 150.0),
  status: 'Submitted'
)
```

### Task 5: Add Convenience Methods and Traits
**Description**: Add convenience methods and trait system for common variations
**Convenience methods**:
- `aapl_stock` - Returns Apple stock
- `msft_stock` - Returns Microsoft stock
- `goog_stock` - Returns Google stock
- `popular_stocks` - Array of popular stock factories
- `common_options` - Array of common option factories

**Traits**:
- `:smart_exchange` - Use SMART exchange
- `:paper_account` - Use paper trading account
- `:day_order` - Day time-in-force
- `:gtc_order` - GTC time-in-force

**Example usage**:
```ruby
# Convenience method
stock = IB::Test::Factory.aapl_stock

# With traits
stock = IB::Test::Factory.aapl_stock(:smart_exchange)
order = IB::Test::Factory.market_order(:paper_account, action: 'BUY', quantity: 100)
```

### Task 6: Create Factory Helper Module
**Description**: Create helper methods for specs using factories
**Methods**:
- `factory` - Accessor to IB::Test::Factory
- `create_contract(type:, **attrs)` - Generic contract creator
- `create_order(type:, **attrs)` - Generic order creator
- `build_message(type:, **attrs)` - Generic message creator

**Integration**: Include in RSpec configuration

**Example usage**:
```ruby
describe "Some test" do
  it "uses factories" do
    stock = factory.aapl_stock
    order = factory.market_order(action: 'BUY', quantity: 100)
  end
end
```

### Task 7: Update spec_helper.rb
**Description**: Ensure factories are loaded in test suite
**Changes**:
- Add require for factories to spec_helper.rb
- Include factory helper module in RSpec configuration
- Ensure factories are available in all tests

### Task 8: Write Example Tests Using Factories
**Description**: Create example tests demonstrating factory usage
**Examples**:
- Creating contracts with factories
- Creating orders with factories
- Using traits and convenience methods
- Complex test scenarios with multiple factories

**Location**: `spec/ib/factories_example_spec.rb`

### Task 9: Document Factory Usage
**Description**: Update documentation with factory examples
**Files to update**:
- `spec/support/mocks/README.md` - Add factory section
- `TESTING.md` (if exists) - Add factory usage guide
- Create `spec/support/factories/README.md` - Factory documentation

**Documentation sections**:
- Factory overview
- Contract factories
- Order factories
- Message factories
- Traits and convenience methods
- Best practices

### Task 10: Run Full Test Suite
**Description**: Ensure factories work correctly with existing tests
**Verification**:
- All existing tests pass
- Factory example tests pass
- No regressions introduced
- Coverage remains or improves

## Success Criteria
- [ ] Factory module loads without errors
- [ ] All contract types have factory methods
- [ ] All order types have factory methods
- [ ] All message types have factory methods
- [ ] Convenience methods and traits work correctly
- [ ] Factory helper module available in specs
- [ ] Example tests demonstrate usage
- [ ] Documentation is comprehensive
- [ ] All existing tests continue to pass
- [ ] Code coverage maintained or improved

## Notes
- Follow existing Ruby/RSpec patterns
- Use keyword arguments for clarity
- Provide sensible defaults
- Support attribute overrides
- Document all factory methods
- Keep factories in sync with IB classes