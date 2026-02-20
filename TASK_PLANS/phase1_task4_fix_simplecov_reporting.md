# Task Plan: Fix SimpleCov Reporting

## Task Description
Ensure coverage reports generate correctly and integrate coverage reporting into test command output.

## Objectives
1. Verify SimpleCov is properly configured in `spec_helper.rb`
2. Ensure coverage reports are generated to `coverage/` directory
3. Add coverage summary output to test command
4. Configure SimpleCov for proper filtering of non-source files
5. Add coverage reporting badge configuration

## Prerequisites
- SimpleCov gem installed (should be in Gemfile)
- Ruby and Bundler installed
- Basic understanding of code coverage tools

## Implementation Steps

### Step 1: Verify SimpleCov Configuration
Check current `spec_helper.rb`:
```bash
grep -A 10 "SimpleCov" spec/spec_helper.rb
```

Expected to see:
```ruby
require 'simplecov'
SimpleCov.start
```

### Step 2: Enhance SimpleCov Configuration
Update `spec_helper.rb` with comprehensive configuration:
```ruby
# Enhanced SimpleCov configuration
require 'simplecov'

SimpleCov.start do
  # Track all Ruby files in lib directory
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'
  
  # Group files by common patterns
  add_group 'Contracts', 'lib/ib/contracts'
  add_group 'Messages', 'lib/ib/messages'
  add_group 'Orders', 'lib/ib/orders'
  add_group 'Plugins', 'lib/ib/plugins'
  add_group 'Core', 'lib/ib'
  
  # Minimum coverage threshold (commented out initially)
  # minimum_coverage 70
  
  # Enable source control tracking (for CI)
  enable_coverage :branch if ENV['CI']
  
  # Formatter configuration
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    # SimpleCov::Formatter::Console,  # Uncomment for console output
    SimpleCov::Formatter::CodeClimateJsonFormatter,
  ])
end
```

### Step 3: Create Custom SimpleCov Formatter
```bash
mkdir -p lib/support
cat > lib/support/coverage_formatter.rb << 'EOF'
module SimpleCov
  class Formatter
    class IBFormatter < SimpleCov::Formatter::HTMLFormatter
      def format(result)
        super
        output_summary(result) if ENV['COVERAGE_SUMMARY']
      end
      
      private
      
      def output_summary(result)
        puts "\n" + "=" * 80
        puts "COVERAGE SUMMARY"
        puts "=" * 80
        puts "Total Lines: #{result.total_lines}"
        puts "Covered Lines: #{result.covered_lines}"
        puts "Coverage Percentage: #{(result.covered_percent * 100).round(2)}%"
        puts "=" * 80 + "\n"
      end
    end
  end
end
EOF
```

### Step 4: Update spec_helper.rb to Use Custom Formatter
Modify SimpleCov configuration:
```ruby
require_relative '../lib/support/coverage_formatter'

SimpleCov.start do
  # ... existing configuration ...
  
  formatter SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::IBFormatter,
  ])
end
```

### Step 5: Create Coverage Summary Rake Task
```bash
cat > lib/tasks/coverage.rake << 'EOF'
namespace :coverage do
  descend
  
  task :show do
    sh 'open coverage/index.html'
  end
  
  task :summary do
    sh 'bundle exec rspec --format progress COVERAGE_SUMMARY=true'
  end
  
  task :html do
    sh 'bundle exec rspec --format progress'
    Rake::Task['coverage:show'].execute
  end
end
EOF
```

### Step 6: Add Coverage Badge Configuration
Create `.github/BADGES.md`:
```markdown
# Coverage Badges

## GitHub Actions Badge
Add this to your README:
```markdown
[![Test Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/YOUR_USERNAME/COVERAGE_GIST_ID/raw/coverage.json)](https://github.com/YOUR_ORG/ib-api/actions)
```

## Code Climate Badge (if using)
```markdown
[![Test Coverage](https://api.codeclimate.com/v1/badges/YOUR_CODECLIMATE_ID/test_coverage)](https://codeclimate.com/github/YOUR_ORG/ib-api/test_coverage)
```

## Local Badge Generation
Run this to generate badge data:
```bash
bundle exec ruby bin/generate_badge.rb
```
EOF
```

### Step 7: Create Badge Generator Script
```bash
cat > bin/generate_badge.rb << 'EOF'
#!/usr/bin/env ruby
require 'json'
require 'simplecov'

# Run coverage analysis
result = SimpleCov.run_load

# Generate badge data
badge_data = {
  schemaVersion: 1,
  label: 'Test Coverage',
  message: "#{result.covered_percent.round}%",
  color: coverage_color(result.covered_percent),
}

# Save to file for GitHub Actions
File.write('.github/coverage.json', JSON.generate(badge_data))

puts "✓ Coverage badge generated"
puts "Coverage: #{(result.covered_percent * 100).round(2)}%"

def coverage_color(percentage)
  if percentage >= 80
    'green'
  elsif percentage >= 60
    'yellow'
  else
    'red'
  end
end
EOF
chmod +x bin/generate_badge.rb
```

### Step 8: Test Coverage Reporting
Run tests with coverage:
```bash
bundle exec rspec --format progress COVERAGE_SUMMARY=true
```

Verify output includes summary:
```
================================================================================
COVERAGE SUMMARY
================================================================================
Total Lines: 4743
Covered Lines: 2767
Coverage Percentage: 58.34%
================================================================================
```

### Step 9: Verify Coverage Report Generation
Check if coverage directory was created:
```bash
ls -la coverage/
```

Open the HTML report:
```bash
open coverage/index.html
```

### Step 10: Document Coverage Workflow
Append to `TESTING.md`:
```markdown
## Code Coverage

### Running Coverage Reports

#### Basic Coverage Report
```bash
bundle exec rspec
```

This generates an HTML report in the `coverage/` directory.

#### Coverage with Summary Output
```bash
bundle exec rspec COVERAGE_SUMMARY=true
```

Displays coverage summary after test run:
```
================================================================================
COVERAGE SUMMARY
================================================================================
Total Lines: 4743
Covered Lines: 2767
Coverage Percentage: 58.34%
================================================================================
```

#### View Coverage Report
```bash
bundle exec rake coverage:html
```

Opens the HTML coverage report in your browser.

### Coverage Groups

Coverage is organized into groups:
- **Contracts**: Contract model implementations
- **Messages**: Incoming and outgoing message handlers
- **Orders**: Order-related functionality
- **Plugins**: Plugin implementations
- **Core**: Core library code

### Coverage Targets

Current coverage goals:
- **Overall**: 75%+
- **Contracts**: 90%+
- **Messages**: 85%+
- **Orders**: 85%+
- **Plugins**: 70%+
- **Core**: 75%+

### Interpreting Coverage Reports

The HTML report shows:
- **Green**: Lines covered by tests
- **Red**: Lines not covered by tests
- **Yellow**: Branches with partial coverage

Click on files to see detailed line-level coverage information.

### CI Coverage Badge

The GitHub Actions workflow generates a coverage badge:
```
[![Test Coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/YOUR_USERNAME/COVERAGE_GIST_ID/raw/coverage.json)](https://github.com/YOUR_ORG/ib-api/actions)
```

To update the badge:
1. Push to main branch (badge updates automatically)
2. Or run locally: `bundle exec ruby bin/generate_badge.rb`

### Branch Coverage

For branch coverage analysis:
```bash
CI=true bundle exec rspec
```

This enables branch coverage tracking (slower but more accurate).

### Code Climate Integration

If using Code Climate:
1. Add `simplecov-codeclimate` to your Gemfile
2. Configure SimpleCov formatter:
   ```ruby
   require 'simplecov'
   SimpleCov.start do
     formatter SimpleCov::Formatter::CodeClimateJsonFormatter
   end
   ```
3. Follow Code Climate setup instructions
```

### Step 11: Add Coverage to Git Ignore
Update `.gitignore`:
```bash
echo "# Coverage reports" >> .gitignore
echo "coverage/" >> .gitignore
```

### Step 12: Create Coverage Baseline
Run once to establish baseline:
```bash
bundle exec rspec --format progress
cp -r coverage coverage-baseline
git add coverage-baseline/
git commit -m "Add coverage baseline"
```

## Success Criteria
- ✅ SimpleCov properly configured with filters and groups
- ✅ Coverage reports generated correctly to `coverage/` directory
- ✅ Summary output displayed when running with `COVERAGE_SUMMARY=true`
- ✅ HTML report viewable and navigation working
- ✅ Coverage documentation added to `TESTING.md`
- ✅ Badge generation script working
- ✅ Rake tasks for coverage operations functional

## Time Estimate: 3-5 hours
