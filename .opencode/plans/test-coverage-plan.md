# Test Coverage Improvement Plan

## Overview
This plan outlines all steps needed to achieve **80%+ coverage** for the 7 critical poorly-covered files in the ib-api Ruby gem.

**Current Overall Coverage:** 44.94%
**Target Overall Coverage:** 80%+
**Estimated Time:** 51-64 hours

---

## Critical Files Requiring Coverage

| File | Current | Target | Lines | Est. Hours |
|------|---------|--------|-------|------------|
| lib/ib/connection.rb | 27.06% | 80% | 573 | 8-10 |
| lib/ib/messages/outgoing/place_order.rb | 11.48% | 80% | 149 | 6-8 |
| models/ib/spread.rb | 20.55% | 80% | 176 | 5-6 |
| models/ib/option.rb | 29.31% | 80% | 149 | 5-6 |
| models/ib/order.rb | 32.86% | 80% | 714 | 8-10 |
| lib/ib/plugins.rb | 20.00% | 80% | 29 | 3-4 |
| Additional files | varies | 80% | varies | 11-14 |

---

## Phase 1: Connection Class (27.06% → 80%)

**File:** `lib/ib/connection.rb` (573 lines, currently 69 covered, need 186 more)
**Priority:** CRITICAL - Core infrastructure
**Estimated Time:** 8-10 hours

### 1.1 Workflow State Management (Lines 33-74)

**Test Requirements:**
- Test workflow_state accessor
- Test all state transitions:
  * :virgin → :ready (via try_connection)
  * :virgin → :gateway_mode (via activate_managed_accounts)
  * :virgin → :lean_mode (via collect_data)
  * :lean_mode → :ready
  * :gateway_mode → :ready
  * :gateway_mode → :account_based_operations
  * :ready → :account_based_operations
  * :ready → :disconnected
  * :disconnected → :ready
  * :disconnected → :gateway_mode
  * :account_based_operations → :disconnected
  * :account_based_operations → :account_based_orderflow
  * :account_based_orderflow → :disconnected
- Test on_transition callback logging

**Implementation Steps:**
1. Create test file: `spec/ib/connection_workflow_spec.rb`
2. Write tests for each state transition
3. Mock socket connections for try_connection transitions
4. Verify workflow_state after each transition
5. Test logging output for on_transition callback

### 1.2 Connection Management (Lines 144-207)

**Test Requirements:**
- Test connected? method in various states
- Test try_connection event (protected method testing via public interface)
- Test disconnect event
- Test reconnect method (lines 237-253)
  * Test reconnect when in :virgin state (should return early)
  * Test reconnect from :ready, :lean_mode, :disconnected
  * Test reconnect from :gateway_mode
  * Test reconnect from :account_based_operations
  * Test reconnect from :account_based_orderflow
  * Test unsubscribe behavior during reconnect

**Implementation Steps:**
1. Add to existing `spec/ib/connection_spec.rb`
2. Create comprehensive reconnect tests
3. Mock socket for connection/disconnection cycles
4. Test each workflow state for reconnect behavior
5. Verify subscribers are properly unsubscribed

### 1.3 Message Subscription System (Lines 256-307)

**Test Requirements:**
- Test subscribe with:
  * Symbol message type
  * Class message type
  * Regexp pattern
  * Block subscriber
  * Proc subscriber
  * Multiple message types at once
  * Error cases (non-callable, invalid message type)
- Test unsubscribe:
  * Single id
  * Multiple ids
  * Non-existent id (error handling)
- Test thread safety with @subscribe_lock

**Implementation Steps:**
1. Create `spec/ib/connection_subscription_spec.rb`
2. Write tests for all subscribe variations
3. Test error conditions
4. Test unsubscribe functionality
5. Verify thread safety (if possible in tests)

### 1.4 Received Messages Management (Lines 310-365)

**Test Requirements:**
- Test received hash initialization
- Test received? method with:
  * Single message type
  * Multiple counts
- Test clear_received:
  * Clear all messages
  * Clear specific message types
  * Thread safety with @receive_lock
- Test wait_for:
  * With message type symbol
  * With [symbol, count] array
  * With callable/block condition
  * With timeout
  * With reader running vs process_messages

**Implementation Steps:**
1. Add to `spec/ib/connection_spec.rb`
2. Test received hash behavior
3. Test wait_for with various conditions
4. Test clear_received functionality
5. Test timeout behavior

### 1.5 Message Processing (Lines 367-571)

**Test Requirements:**
- Test reader_running? method
- Test start_reader (protected, test via integration)
- Test process_messages:
  * Normal message processing
  * Socket shutdown detection
  * Windows vs non-Windows behavior
  * Errno::ECONNRESET handling
- Test process_message:
  * Valid message processing
  * Unsupported message type
  * Zero message id (reader restart needed)
  * TransmissionError handling
  * Subscriber delivery
  * No subscribers warning
  * Received hash collection
- Test satisfied? method:
  * Symbol conditions
  * Array conditions
  * Callable conditions
  * Empty conditions
  * Unknown condition type
- Test random_id method

**Implementation Steps:**
1. Create `spec/ib/connection_processing_spec.rb`
2. Mock socket and parser for message processing
3. Test various message scenarios
4. Test error handling
5. Test subscriber delivery

---

## Phase 2: PlaceOrder Message (11.48% → 80%)

**File:** `lib/ib/messages/outgoing/place_order.rb` (149 lines, currently 7 covered, need 54 more)
**Priority:** CRITICAL - Order placement
**Estimated Time:** 6-8 hours

### 2.1 Order Encoding Logic (Lines 8-145)

**Test Requirements:**
Test encode method with all order types:
- Basic limit order
- Market order
- Stop order
- Stop-limit order
- Trailing stop order
- Volatility order
- Scale order
- Bracket order (with parent_id)
- OCA group order
- Iceberg order (display_size)
- Hidden order
- Block order
- Sweep-to-fill order
- All-or-none order
- Good-after-time order
- Good-till-date order
- Outside RTH order
- Hedge order (delta, beta, FX, pair)
- Algo order
- Pegged order
- Combo/Bag order
- EFP order
- Box order
- Auction order
- Discretionary order
- Financial advisor orders
- Institutional orders
- Clearing orders
- Delta neutral orders
- MIFID II orders
- Conditions-based orders
- Soft dollar tier orders
- Random size/price orders
- Manual time orders
- Auto-cancel parent orders
- Post to ATS orders
- Duration orders
- Price management algo orders
- Professional/customer account orders

### 2.2 Contract Handling (Lines 10-13)

**Test Requirements:**
- Test contract extraction from order
- Test contract validation
- Test error when contract not specified
- Test contract serialization with different contract types

### 2.3 Field Serialization (Lines 17-144)

**Test Requirements:**
Test each serialize_* method call:
- serialize_short on contract
- serialize_main_order_fields
- serialize_extended_order_fields
- serialize_combo_legs
- serialize_auxilery_order_fields
- serialize_advanced_option_order_fields
- serialize_volatility_order_fields
- serialize_delta_neutral_order_fields
- serialize_scale_order_fields
- serialize_algo
- serialize_misc_options
- serialize_pegged_order_fields
- serialize_conditions
- serialize_soft_dollar_tier
- serialize_mifid_order_fields
- serialize_peg_best_and_mid
- serialize_under_comp on contract

**Implementation Steps:**
1. Create `spec/ib/messages/outgoing/place_order_spec.rb`
2. Create test data factories for various order types
3. Test each order type encoding
4. Verify field serialization
5. Test error conditions

---

## Phase 3: Spread Model (20.55% → 80%)

**File:** `models/ib/spread.rb` (176 lines, currently 15 covered, need 59 more)
**Priority:** HIGH - Complex spreads
**Estimated Time:** 5-6 hours

### 3.1 Class Methods (Lines 17-39)

**Test Requirements:**
- Test transform_distance with:
  * Absolute date format (YYYYMM, YYYYMMDD)
  * Relative week format ({n}w)
  * Relative month format ({n}m)
  * Edge cases: invalid formats, negative values
  * Date calculations with weekends/holidays

### 3.2 Instance Methods (Lines 41-118)

**Test Requirements:**
- Test to_human method
- Test calculate_spread_value with:
  * Valid portfolio values array
  * Block parameter
  * Empty array
  * Invalid input
- Test fake_portfolio_position with:
  * Valid portfolio values
  * Calculation of aggregated values
  * Edge cases

### 3.3 Leg Management (Lines 65-107)

**Test Requirements:**
- Test add_leg with:
  * Valid contract
  * Various leg_params (action, weight, ratio, description)
  * Invalid contract (non-Contract object)
  * Contract without con_id
  * Multiple legs
  * Method chaining
- Test remove_leg with:
  * Contract object parameter
  * Position index parameter
  * Invalid parameter
  * Non-existent contract
  * Method chaining

### 3.4 Utility Methods (Lines 109-175)

**Test Requirements:**
- Test essential method (cloning)
- Test multiplier calculation
- Test con_id generation (negative sum of leg con_ids)
- Test as_table method (Terminal::Table output)
- Test build_from_json class method
  * Valid JSON container
  * Missing fields
  * Invalid data

**Implementation Steps:**
1. Expand `spec/ib/spread_spec.rb`
2. Create test data for various spread types
3. Test all leg management operations
4. Test date transformation logic
5. Test JSON serialization/deserialization

---

## Phase 4: Option Model (29.31% → 80%)

**File:** `models/ib/option.rb` (149 lines, currently 17 covered, need 46 more)
**Priority:** HIGH - Options trading
**Estimated Time:** 5-6 hours

### 4.1 Validations (Lines 4-10)

**Test Requirements:**
- Test strike validation (numericality, greater_than: 0)
  * Valid strikes
  * Zero strike (invalid)
  * Negative strike (invalid)
  * Non-numeric (invalid)
- Test sec_type validation (format: /\Aoption\z/)
  * Valid :option
  * Invalid values
- Test local_symbol validation (OSI code format)
  * Valid OSI codes
  * Invalid formats
  * Empty string (allowed)
- Test right validation (put/call)
  * Valid :put, :call
  * Valid "put", "call"
  * Invalid values

### 4.2 OSI Code Handling (Lines 17-22)

**Test Requirements:**
- Test osi getter (alias for local_symbol)
- Test osi= setter
  * Normalization to 21 characters
  * Various input formats

### 4.3 Class Method from_osi (Lines 29-50)

**Test Requirements:**
- Test parsing valid OSI codes
  * Format: SYMBOL YYMMDD RIGHT STRIKE
  * Various symbols
  * Different dates
  * Put and call
  * Various strikes
- Test IB expiry date adjustment
  * When expiry falls on Saturday
  * Normal expiry dates
- Test returned Option attributes
  * symbol, exchange, expiry, right, strike

### 4.4 Instance Method next_expiry (Lines 86-103)

**Test Requirements:**
- Test with Date object
- Test with parseable string
- Test with integer
- Test with block parameter
- Test when verify plugin available
  * Loop until valid option found
  * Date decrement logic
  * Error when no suitable expiry
- Test when verify plugin not available
  * Return merged option without verification

### 4.5 Class Method next_expiry (Lines 112-136)

**Test Requirements:**
- Test with Date object
- Test with string
- Test with integer (day of month)
- Test with yymm format
- Test with yyyymm format
- Test with yyyymmdd format
- Test Date::Error handling
- Test third Friday calculation
- Test when base date is past the third Friday (next month logic)

### 4.6 Display Methods (Lines 138-140)

**Test Requirements:**
- Test to_human output format

**Implementation Steps:**
1. Expand `spec/ib/option_spec.rb`
2. Test all validation scenarios
3. Test OSI parsing and generation
4. Test expiry calculations
5. Test verify plugin integration

---

## Phase 5: Order Model (32.86% → 80%)

**File:** `models/ib/order.rb` (714 lines, currently 46 covered, need 94 more)
**Priority:** HIGH - Order management
**Estimated Time:** 8-10 hours

### 5.1 Property Definitions (Lines 14-441)

**Test Requirements:**
- Test all prop definitions exist
- Test default values from default_attributes
- Test property types (bool, string, int, etc.)
- Test aliases (side/action)

### 5.2 Default Attributes (Lines 372-441)

**Test Requirements:**
- Test all default values are set correctly
- Test conditional defaults based on server_version
- Test complex defaults (hashes, arrays, objects)

### 5.3 Serialization Methods (Lines 444-493)

**Test Requirements:**
- Test serialize_combo_legs
  * With bag contract
  * With non-bag contract
  * With leg_prices
  * With combo_params
- Test serialize_main_order_fields
  * Side conversion (:short → 'SSHORT', etc.)
  * Total quantity formatting
  * Order type internal code
  * Limit price and aux_price
- Test serialize_extended_order_fields
  * All TIF values
  * OCA group
  * Account
  * Open/close
  * Origin
  * Order ref
  * Transmit flag
  * Parent ID
  * Block order
  * Sweep to fill
  * Display size
  * Trigger method
  * Outside RTH
  * Hidden
- Test serialize_auxilery_order_fields
  * Shares allocation (deprecated)
  * Discretionary amount
  * Good after time
  * Good till date
  * Advisory fields

### 5.4 Order State Management (Lines 320-363)

**Test Requirements:**
- Test order_state getter
- Test order_state= setter
  * With OrderState object
  * With Symbol
  * With String
- Test delegated properties:
  * Commission properties
  * Status properties
  * Fill properties (filled, remaining, price, etc.)
  * State predicates (new?, submitted?, pending?, active?, inactive?, complete_fill?)
  * Margin properties (init_margin, equity_with_loan, maint_margin)

### 5.5 Validations (Lines 365-369)

**Test Requirements:**
- Test numericality validations
  * Integer fields (local_id, perm_id, client_id, parent_id, total_quantity, min_quantity, display_size)
  * Float fields (limit_price, aux_price)
  * allow_nil behavior

**Implementation Steps:**
1. Expand `spec/ib/order_spec.rb`
2. Create test data factories for various order types
3. Test each serialization method
4. Test order state transitions
5. Test all validations

---

## Phase 6: Plugins System (20.00% → 80%)

**File:** `lib/ib/plugins.rb` (29 lines, currently 3 covered, need 24 more)
**Priority:** MEDIUM - Plugin infrastructure
**Estimated Time:** 3-4 hours

### 6.1 Plugin Activation (Lines 3-27)

**Test Requirements:**
- Test activate_plugin with:
  * Single plugin name (symbol)
  * Single plugin name (string)
  * Multiple plugin names
  * Plugin name with underscores (converted to dashes)
  * Already activated plugin (should skip)
  * Non-existent plugin (should error)
  * Plugin that raises LoadError (should error gracefully)
- Test plugin loading:
  * Verify file existence check
  * Verify require functionality
  * Verify @plugins array update
- Test error handling:
  * LoadError with message
  * Missing plugin file

**Implementation Steps:**
1. Create `spec/ib/plugins_spec.rb`
2. Create mock plugin files for testing
3. Test activation with various scenarios
4. Test error conditions
5. Verify plugin tracking

---

## Phase 7: Additional Poorly Covered Files

### 7.1 Contract Model (39.32% → 80%)
**File:** `models/ib/contract.rb` (411 lines)
**Estimated Time:** 4-5 hours

**Test Requirements:**
- Test all validation scenarios
- Test contract verification logic
- Test serialization methods
- Test comparison operators
- Test attribute inheritance
- Test exchange handling
- Test currency handling
- Test con_id-based operations

### 7.2 Socket Class (32.14% → 80%)
**File:** `lib/ib/socket.rb` (83 lines)
**Estimated Time:** 3-4 hours

**Test Requirements:**
- Test socket opening/closing
- Test message sending/receiving
- Test handshake process
- Test error handling (connection refused, timeout)
- Test platform-specific behavior (Windows vs Unix)

### 7.3 Support Module (38.14% → 80%)
**File:** `lib/ib/support.rb` (236 lines)
**Estimated Time:** 4-5 hours

**Test Requirements:**
- Test all utility methods
- Test logging functionality
- Test data formatting methods
- Test error handling helpers
- Test type conversion methods

---

## Implementation Timeline

| Phase | Component | Current | Target | Est. Hours | Dependencies |
|-------|-----------|---------|--------|------------|--------------|
| 1 | Connection | 27.06% | 80% | 8-10 | None |
| 2 | PlaceOrder | 11.48% | 80% | 6-8 | Phase 1 |
| 3 | Spread | 20.55% | 80% | 5-6 | Phase 1 |
| 4 | Option | 29.31% | 80% | 5-6 | Phase 1 |
| 5 | Order | 32.86% | 80% | 8-10 | Phase 2 |
| 6 | Plugins | 20.00% | 80% | 3-4 | Phase 1 |
| 7 | Additional | varies | 80% | 11-14 | Phases 1-6 |
| **Total** | | **44.94%** | **80%+** | **51-64 hours** | |

---

## Testing Strategy

### 1. Unit Tests (70% of effort)
- Test individual methods in isolation
- Mock external dependencies (socket, TWS)
- Use factories for test data
- Test edge cases and error conditions

### 2. Integration Tests (20% of effort)
- Test component interactions
- Use socket stubs for realistic message flow
- Test workflow state transitions
- Test plugin activation and usage

### 3. Shared Examples (10% of effort)
- Create reusable test patterns
- Share between similar test files
- Document expected behaviors

---

## Success Metrics

- **Overall Coverage:** 44.94% → 80%+
- **Critical Files:** All ≥80%
- **Test Count:** 53 → 120+ spec files
- **Test Reliability:** <1% flaky tests
- **Test Speed:** <5 minutes full suite

---

## Next Steps

1. **Review this plan** - Do you want to adjust priorities or scope?
2. **Set up test environment** - Ensure socket stubs and mocks are ready
3. **Begin Phase 1** - Start with Connection class (highest impact)
4. **Weekly check-ins** - Review progress and adjust timeline

Would you like me to:
- Start implementing Phase 1 (Connection tests)?
- Create a more detailed breakdown for any specific phase?
- Adjust the timeline or priorities?
- Generate test templates for any specific file?