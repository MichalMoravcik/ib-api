# Task Plan: Add Test Configuration Documentation

## Task Description
Document required `spec/spec.yml` structure, provide example configurations for different environments, and add troubleshooting guide for common test setup issues.

## Objectives
1. Create comprehensive documentation for test configuration
2. Provide examples for development, CI, and production-like environments
3. Document common setup issues and their solutions
4. Make configuration requirements clear for contributors

## Prerequisites
- Existing `spec/spec.yml` (or create template)
- Understanding of test requirements from spec_helper.rb
- Knowledge of common IB TWS connection parameters

## Implementation Steps

### Step 1: Create TESTING.md Documentation File
```bash
cat > TESTING.md << 'EOF'
# Testing Guide for IB API

## Getting Started

### Prerequisites
- Ruby 2.7+
- Bundler
- Interactive Brokers TWS or IB Gateway (for integration tests)

### Installation
```bash
bundle install
```

## Configuration

### Basic Configuration (`spec/spec.yml`)

Create a `spec/spec.yml` file with your IB connection details:

```yaml
# Minimum required configuration
connection:
  host: localhost      # TWS/Gateway host
  port: 7496           # TWS/Gateway port (4001 for paper trading)
  client_id: 123456    # Unique client ID
  account: "U1234567"  # Your IB account number
  
stock:
  symbol: AAPL         # Sample stock for tests
  sec_type: STK        # Security type
  exchange: SMART      # Exchange
  currency: USD        # Currency
```

### Example Configurations

#### Development Environment
```yaml
connection:
  host: localhost
  port: 7496
  client_id: 00001
  account: "U123456"
  
stock:
  symbol: AAPL
  sec_type: STK
  exchange: SMART
  currency: USD
```

#### Paper Trading Environment
```yaml
connection:
  host: localhost
  port: 4001          # Paper trading port
  client_id: 99999
  account: "DU123456" # Paper trading account
  
stock:
  symbol: AAPL
  sec_type: STK
  exchange: SMART
  currency: USD
```

#### CI Environment (using mock server)
```yaml
connection:
  host: localhost
  port: 7496          # Mock server port
  client_id: 123456
  account: "U1234567"
  
use_mock_server: true

stock:
  symbol: AAPL
  sec_type: STK
  exchange: SMART
  currency: USD
```

### Environment-Specific Configurations

You can use different configuration files based on environment:

```bash
# Use custom config file
SPEC_CONFIG=spec/ci_spec.yml bundle exec rspec
```

## Running Tests

### Run All Tests
```bash
bundle exec rspec
```

### Run Specific Test File
```bash
bundle exec rspec spec/ib/stock_spec.rb
```

### Run Specific Test Example
```bash
bundle exec rspec spec/ib/stock_spec.rb -e "creates valid stock contract"
```

### Run Tests with Mock Server
```bash
USE_MOCK_SERVER=true bundle exec rspec
```

### Verbose Output
```bash
bundle exec rspec --format documentation
```

## Common Issues and Solutions

### Issue: All Tests Failing with Connection Errors
**Symptoms**:
- Tests fail with "Connection refused" or timeout errors
- Error messages about unable to connect to TWS/Gateway

**Solutions**:
1. Verify TWS/Gateway is running
2. Check port number in `spec/spec.yml`
3. Ensure client_id is unique (not used by other applications)
4. Run tests with mock server: `USE_MOCK_SERVER=true bundle exec rspec`

### Issue: Invalid Account Number
**Symptoms**:
- Tests fail with account-related errors
- Error messages about invalid account

**Solutions**:
1. Verify account number in `spec/spec.yml`
2. Use correct prefix (U for real accounts, DU for paper trading)
3. Ensure account has proper permissions

### Issue: Zeitwerk Loader Errors
**Symptoms**:
- "uninitialized constant" errors
- "expected file ... but didn't find it"

**Solutions**:
1. Run `bundle exec rake tmp:clear` to clear cache
2. Restart your terminal session
3. Ensure all required gems are installed (`bundle install`)

### Issue: SimpleCov Coverage Not Generated
**Symptoms**:
- No coverage report in `coverage/` directory
- Tests run but no HTML output

**Solutions**:
1. Ensure SimpleCov is required before other code in `spec_helper.rb`
2. Run tests with coverage explicitly: `COVERAGE=true bundle exec rspec`
3. Check file permissions in project directory

### Issue: Slow Test Execution
**Symptoms**:
- Tests take a long time to run
- Timeouts during execution

**Solutions**:
1. Use mock server instead of real connection
2. Run only unit tests: `bundle exec rspec spec/ib/contracts/`
3. Skip integration tests with tag filtering

## Test Organization

### Test Structure
```
spec/
├── spec_helper.rb          # Main test configuration
├── support/                # Test support files
│   ├── model_helper.rb     # Model testing utilities
│   ├── order_helper.rb     # Order testing utilities
│   └── ...                 # Other helpers
├── ib/                     # Main test suite
│   ├── contracts/          # Contract model tests
│   ├── messages/           # Message handling tests
│   ├── orders/             # Order-related tests
│   └── ...                 # Other modules
```

### Test Types

#### Unit Tests
- Fast, isolated tests
- No external dependencies
- Example: `spec/ib/stock_spec.rb`

#### Integration Tests
- Test interaction with real IB TWS/Gateway
- Require proper configuration
- Example: `spec/ib/orders/trades_spec.rb`

#### Mock Tests
- Use mock TWS server
- Fast and reliable
- Example: `spec/ib/mocks_spec.rb`

## Writing New Tests

### Basic Test Structure
```ruby
describe IB::Stock do
  Given(:symbol) { 'AAPL' }
  
  describe "contract creation" do
    it "should create valid stock contract" do
      contract = IB::Stock.new(symbol: symbol)
      expect(contract).to be_valid
    end
  
    it "should validate required fields" do
      contract = IB::Stock.new(symbol: nil)
      expect(contract).not_to be_valid
    end
  end
end
```

### Using Shared Examples
```ruby
describe IB::Stock do
  it_has_message 'has validations', shared: :valid_model
end
```

### Testing with Mock Server
```ruby
describe "Integration with mock server" do
  Given(:mock_server) { IB::Test::MockServer.new }
  
  before do
    mock_server.start
  end
  
  after do
    mock_server.stop
  end
  
  it "should connect successfully" do
    connection = IB::Connection.new(host: 'localhost', port: 7496)
    expect(connection.connect).to be_true
  end
end
```

## Advanced Features

### Custom Matchers
Check `spec/support/matchers.rb` for custom RSpec matchers.

### Helpers
Test helpers provide reusable testing patterns:
- `model_helper.rb`: Model validation and property testing
- `order_helper.rb`: Order creation and placement utilities
- `contract_helper.rb`: Contract building functions

### Configuration Options
```ruby
# In spec_helper.rb
OPTS = {
  verbose: true,        # Verbose test output
  use_mock_server: false, # Use mock server instead of real connection
  slow_tests: false      # Run integration tests (slower)
}
```

Run with custom options:
```bash
USE_MOCK_SERVER=true bundle exec rspec
```

## CI/CD Integration

See `.github/workflows/test.yml` for GitHub Actions configuration.

## Support

For issues with testing:
1. Check this documentation first
2. Create a minimal reproduction case
3. Report issues with configuration details
EOF
```

### Step 2: Create Example Configuration Files
```bash
cat > spec/spec.example.yml << 'EOF'
# Example configuration file for IB API tests
# Copy this to spec/spec.yml and edit with your values

connection:
  host: localhost      # TWS/Gateway host address
  port: 7496           # Default TWS port (use 4001 for paper trading)
  client_id: 123456    # Unique client ID for this application
  account: "U1234567"  # Your IB account number (use DUxxxxx for paper trading)

stock:
  symbol: AAPL         # Sample stock symbol for tests
  sec_type: STK        # Security type (STK, OPT, FUT, etc.)
  exchange: SMART      # Exchange (SMART for default routing)
  currency: USD        # Currency (USD, EUR, etc.)

# Optional settings
options:
  log_level: debug     # Logging level (debug, info, warn, error)
  timeout: 30          # Connection timeout in seconds
EOF
```

### Step 3: Create CI-Specific Configuration
```bash
cat > spec/ci_spec.example.yml << 'EOF'
# CI-specific configuration using mock server
# This file is used in continuous integration environments

connection:
  host: localhost      # Mock server will run on localhost
  port: 7496           # Default mock server port
  client_id: 00001     # Fixed client ID for CI
  account: "U1234567"  # Sample account number

stock:
  symbol: AAPL
  sec_type: STK
  exchange: SMART
  currency: USD

# CI-specific settings
ci:
  use_mock_server: true      # Use mock server instead of real connection
  record_cassettes: false    # Don't record new cassettes in CI
  use_recorded_cassettes: true # Use existing cassette recordings
EOF
```

### Step 4: Add Troubleshooting Guide
Append to TESTING.md:

```markdown
## Troubleshooting

### Debugging Test Failures

#### Enable Verbose Logging
```bash
bundle exec rspec --format documentation
```

#### Check Specific Test Output
```bash
bundle exec rspec spec/ib/stock_spec.rb:45
```

#### Inspect Test Object State
Add `binding.irb` or `save_and_open_page` (for Capybara) to debug:
```ruby
it "should create contract" do
  contract = IB::Stock.new(symbol: 'AAPL')
  binding.pry  # Drop into debugger
end
```

#### Common Error Patterns

**Error**: `uninitialized constant IB::Stock`
- **Cause**: Zeitwerk loader issue or missing require
- **Solution**: Clear cache and restart: `bundle exec rake tmp:clear`

**Error**: `No such file or directory @ rb_sysopen - spec/spec.yml`
- **Cause**: Missing configuration file
- **Solution**: Copy `spec/spec.example.yml` to `spec/spec.yml` and edit

**Error**: `Connection refused (errno::ECONNREFUSED)`
- **Cause**: TWS/Gateway not running or wrong port
- **Solution**: Start TWS/Gateway or use mock server

**Error**: `Invalid account`
- **Cause**: Incorrect account number in configuration
- **Solution**: Verify account number format (Uxxxxxx for real, DUxxxxxx for paper)

**Error**: `Timeout waiting for response`
- **Cause**: Network issues or slow connection
- **Solution**: Increase timeout in configuration or use mock server

### Configuration Validation

Validate your `spec/spec.yml` file:
```bash
bundle exec ruby -e "
require 'yaml'
config = YAML.load_file('spec/spec.yml')
puts 'Configuration loaded successfully:'
puts config.inspect
"
```

### Checking Test Dependencies

Ensure all test dependencies are available:
```bash
bundle exec ruby -e "
require './spec/spec_helper'
puts 'All dependencies loaded successfully'
"
```

### Running Specific Test Scenarios

#### Run Unit Tests Only
```bash
bundle exec rspec spec/ib/contracts/ --tag ~integration
```

#### Run Integration Tests Only
```bash
bundle exec rspec --tag integration
```

#### Run Mock Tests Only
```bash
bundle exec rspec spec/ib/mocks_spec.rb --format documentation
```

### Performance Testing

Check test execution time:
```bash
bundle exec rspec --profile
```

Find slowest tests:
```bash
bundle exec rspec --profile 10
```

### Memory Profiling

Check for memory leaks:
```bash
bundle exec rspec --profile 5 -f d
```
EOF
```

### Step 5: Update Spec Helper Documentation
Add comments to `spec/spec_helper.rb`:

```ruby
# Configuration Guide: See TESTING.md for detailed setup instructions
# 
# Required configuration in spec/spec.yml:
# - connection: hash with host, port, client_id, account
# - stock: hash with contract parameters (symbol, sec_type, exchange, currency)
# 
# Optional environment variables:
# - USE_MOCK_SERVER=true: Use mock TWS server instead of real connection
# - RECORD_CASSETTE=true: Record new cassette responses
# - USE_CASSETTE=true: Use recorded cassette responses
```

### Step 6: Create Configuration Validation Script
```bash
cat > bin/validate_config.rb << 'EOF'
#!/usr/bin/env ruby
require 'yaml'
require 'pp'

def validate_config(file = 'spec/spec.yml')
  unless File.exist?(file)
    puts "ERROR: Configuration file #{file} not found"
    puts "Please copy spec/spec.example.yml to #{file} and edit it"
    exit 1
  end
  
  begin
    config = YAML.load_file(file)
  rescue => e
    puts "ERROR: Failed to parse #{file}: #{e.message}"
    exit 1
  end
  
  required_sections = [:connection, :stock]
  required_connection_keys = [:host, :port, :client_id, :account]
  required_stock_keys = [:symbol, :sec_type, :exchange, :currency]
  
  puts "Validating configuration..."
  
  # Check required sections
  missing_sections = required_sections - config.keys.map(&:to_sym)
  unless missing_sections.empty?
    puts "ERROR: Missing required sections: #{missing_sections.join(', ')}"
    exit 1
  end
  
  # Check connection section
  missing_conn = required_connection_keys - config[:connection].keys.map(&:to_sym)
  unless missing_conn.empty?
    puts "ERROR: Missing required connection keys: #{missing_conn.join(', ')}"
    exit 1
  end
  
  # Check stock section
  missing_stock = required_stock_keys - config[:stock].keys.map(&:to_sym)
  unless missing_stock.empty?
    puts "ERROR: Missing required stock keys: #{missing_stock.join(', ')}"
    exit 1
  end
  
  puts "✓ Configuration validation successful"
  puts "\nConfiguration summary:"
  pp config
end

validate_config(ARGV.first || 'spec/spec.yml')
EOF
chmod +x bin/validate_config.rb
```

### Step 7: Add Configuration to Rake Tasks
Create `lib/tasks/test.rake`:
```ruby
namespace :test do
  desc "Validate test configuration"
  task :validate_config => 'bin/validate_config.rb'
  
  desc "Run unit tests"
  task :unit do
    sh 'bundle exec rspec spec/ib/contracts/ spec/ib/messages/ spec/ib/stock_spec.rb --tag ~integration'
  end
  
  desc "Run integration tests"
  task :integration do
    sh 'bundle exec rspec --tag integration'
  end
  
  desc "Run all tests"
  task :all do
    Rake::Task['test:unit'].execute
    Rake::Task['test:integration'].execute
  end
end
```

## Success Criteria
- ✅ Comprehensive `TESTING.md` documentation created
- ✅ Example configuration files provided (`spec.example.yml`, `ci_spec.example.yml`)
- ✅ Troubleshooting guide with common issues and solutions
- ✅ Configuration validation script working
- ✅ Rake tasks for test execution added
- ✅ Documentation integrated into `spec_helper.rb`

## Time Estimate: 4-6 hours
