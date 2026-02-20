# IB API - Development Guidelines

This document provides guidelines for development and maintenance of the `ib-api` Ruby gem, a wrapper for Interactive Brokers' TWS API.

## Table of Contents

- [Build/Lint/Test Commands](#buildlinttest-commands)
- [Code Style Guidelines](#code-style-guidelines)
  - [Imports and Dependencies](#imports-and-dependencies)
  - [Formatting](#formatting)
  - [Naming Conventions](#naming-conventions)
  - [Error Handling](#error-handling)
  - [Testing](#testing)

## Build/Lint/Test Commands

### Running Tests

- **Run all tests**:
  ```bash
  bundle exec rspec
  # or
  bundle exec rake spec
  ```

- **Run a specific test file**:
  ```bash
  bundle exec rspec spec/path/to/file_spec.rb
  ```

- **Run a specific test (context/describe block)**:
  ```bash
  bundle exec rspec spec/path/to/file_spec.rb -e "context name"
  ```

- **Run tests with Guard (auto-run on file changes)**:
  ```bash
  bundle exec guard
  ```

- **Run individual test methods**:
  Use the `-e` flag with the example description:
  ```bash
  bundle exec rspec spec/path/to/file_spec.rb -e "should do something"
  ```

### Development Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Run interactive console:
   ```bash
   bin/console
   ```

3. Run tests continuously with Guard:
   ```bash
   bundle exec guard
   ```

## Code Style Guidelines

### Imports and Dependencies

1. **Require structure**:
   - Use `require` for core dependencies at the top of files
   - Place `require "zeitwerk"` before ActiveSupport calls
   - Group requires by category (stdlib, gems, local files)

2. **Zeitwerk loader**:
   - Use Zeitwerk for automatic loading in `lib/ib-api.rb`
   - Explicitly ignore files that should not be auto-loaded
   - Configure inflections for class name transformations

3. **Common imports**:
   ```ruby
   require "zeitwerk"
   require "active_model"
   require 'active_support/concern'
   require 'bigdecimal/util'   # provides .to_d for numeric and string classes
   ```

### Formatting

1. **Indentation**: Use 2 spaces (no tabs)
2. **Line length**: Keep lines under 80-100 characters
3. **String quotes**: Prefer single quotes for strings, double quotes only when needed for interpolation
4. **Method chaining**: Chain methods with newlines and consistent indentation:
   ```ruby
   result = some_object
     .method_one
     .method_two(argument)
     .method_three
   ```

5. **Hash syntax**: Use the new Ruby 1.9 hash syntax:
   ```ruby
   # Good
   { key: value, other_key: 'value' }
   
   # Avoid
   { :key => value, :other_key => 'value' }
   ```

### Naming Conventions

1. **Classes and Modules**: Use PascalCase (CamelCase)
   ```ruby
   module IB
     class Contract
       # ...
     end
   end
   ```

2. **Methods and Variables**: Use snake_case
   ```ruby
   def place_order(order, contract)
     local_id = connection.place_order(order, contract)
     # ...
   end
   ```

3. **Constants**: Use UPPER_SNAKE_CASE
   ```ruby
   VALUES = { sec_type: {...} }
   ```

4. **Boolean methods**: Prefix with question mark for predicates:
   ```ruby
   def valid?
     errors.empty?
   end
   ```

5. **Destructive methods**: Suffix with exclamation mark:
   ```ruby
   def clear_received(message_type = nil)
     # ...
   end
   ```

### Error Handling

1. **Custom errors**: Define in `lib/ib/errors.rb`
2. **Validation patterns**: Use ActiveModel validations
   ```ruby
   validates :symbol, presence: true
   validates :expiry, format: { with: /\d{6}/, message: "should be YYYYMM" }
   ```

3. **Error messages**: Use descriptive error strings:
   ```ruby
   validates_each :sec_type do |record, attr, value|
     record.errors.add(attr, "should be valid security type") unless IB::VALUES[:sec_type].key?(value.to_sym)
   end
   ```

4. **Exception handling**: Use specific exception classes:
   ```ruby
   def verify(*symbols)
     symbols.flatten.each do |symbol|
       raise IB::VerifyError, "Something went wrong" unless valid?
     end
   end
   ```

### Testing

1. **Test structure**: Use RSpec with shared examples
   ```ruby
   describe IB::Stock do
     before(:all) { establish_connection }
     after(:all) { close_connection }
     
     describe "Equality of Stock Contracts" do
       Given(:msft) { IB::Symbols::Stocks.msft }
       Then { msft.is_a? IB::Stock }
     end
   end
   ```

2. **Shared examples**: Define reusable test patterns in `spec/*_helper.rb`
   ```ruby
   RSpec.shared_examples_for 'Valid Model' do
     it 'validates' do
       subject.should be_valid
       subject.errors.should be_empty
     end
   end
   ```

3. **Test organization**:
   - Place tests in `spec/` directory matching lib structure
   - Use `spec/spec_helper.rb` for test configuration
   - Configure connection settings in `spec/spec.yml`

4. **Integration tests**: Use helper methods for common patterns:
   ```ruby
   def place_the_order(contract: IB::Symbols::Stocks.wfc)
     order = yield(get_contract_price(contract: contract))
     IB::Connection.current.place_order(order, contract)
   end
   ```

### Model Development

1. **Base class**: Extend `IB::Base` for new models:
   ```ruby
   module IB
     class Contract < Base
       # ...
     end
   end
   ```

2. **Property definitions**: Use the `prop` macro:
   ```ruby
   prop :symbol, :local_symbol,
        :exchange, :currency,
        :primary_exchange, :sec_type
   ```

3. **Validation patterns**: Validate properties with options:
   ```ruby
   prop :expiry, validate: { 
     format: { with: /\d{6}|\d{8}/, message: "should be YYYYMM or YYYYMMDD" }
   }
   ```

4. **Default values**: Use `default_attributes` method:
   ```ruby
   def default_attributes
     { created_at: Time.now }
   end
   ```

### Message Handling

1. **Incoming messages**: Extend `IB::Messages::Incoming::AbstractMessage`
2. **Outgoing messages**: Extend `IB::Messages::Outgoing::AbstractMessage`
3. **Message parsing**: Use Ox for XML parsing when needed

### Plugins

1. **Plugin structure**: Create in `plugins/` directory
2. **Activation**: Use `activate_plugin` method:
   ```ruby
   ib = IB::Connection.current
   ib.activate_plugin 'verify'
   ```

## Additional Notes

1. **Code conventions**: Follow Rails/ActiveModel conventions where possible
2. **Type safety**: Use BigDecimal for financial values, Time/DateTime for timestamps
3. **Immutability**: Avoid modifying objects after creation when possible
4. **Documentation**: Use RDoc-style comments for public APIs
5. **Encoding values**: Use the `VALUES` and `CODES` constants for enumerated properties:
   ```ruby
   VALUES[:sec_type] = {
     stock: 'STK',
     option: 'OPT'
   }
   ```
