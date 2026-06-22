# IB API — Agent Notes

Compact, repo-specific guidance for working on the `ib-api` Ruby gem.

## Build / Test / Run

- **Install deps**: `bundle install`
- **Run unit tests** (no TWS required):
  - `bundle exec rspec`
  - `bundle exec rake spec`
  - `bundle exec guard` — continuous test runner
- **Run integration tests** (requires live TWS/IB Gateway, configured in `spec/spec.yml`):
  - `TEST_ENV=real bundle exec rspec --tag integration`
  - `rake integration`
- **Run a single example**: `bundle exec rspec spec/path/to/file_spec.rb -e "example name"`
- **Console** (requires `bin/console.yml`):
  - `bin/console g` — connect to Gateway (default)
  - `bin/console t` — connect to TWS
- **Gem build/publish**: `bundle exec rake build|install|release`
  - Note: gemspec file is `api.gemspec`, gem name is `ib-api`.
- **No linter/formatter is configured** — there is no RuboCop, StandardRB, or similar tool in the repo.

## Test Suite Tags & Filters

`spec/spec_helper.rb` and `Rakefile` exclude these unless explicitly enabled:

| Tag | Enabled when |
|-----|--------------|
| `:integration` | `TEST_ENV=real` |
| `:connected` | `TEST_ENV=real` |
| `:slow` | `SLOW_TESTS=true` |
| `:focus` | `fit`/`fdescribe` present, or `config.filter_run_when_matching focus: true` |
| `:reuters` | No global enable; used by `spec/ib/integration/fundamental_data_spec.rb` |

The default `rake spec`/`bundle exec rspec` run is unit-test only with `--tag ~integration --tag ~connected --tag ~slow`.

## Code Loading Architecture (Zeitwerk)

Entry point is `lib/ib-api.rb`. It uses `Zeitwerk::Loader.for_gem` and pushes two extra root dirs:

- `models/` → e.g. `models/ib/stock.rb` becomes `IB::Stock`
- `conditions/` → e.g. `conditions/ib/price_condition.rb` becomes `IB::PriceCondition`

Files **ignored by Zeitwerk** and loaded manually or not at all:

- `lib/server_versions.rb`
- `lib/ib-api.rb` itself
- `lib/ib/contract.rb` — reopened after loader setup
- `lib/ib/order_condition.rb` — reopened after loader setup
- `lib/ib/constants.rb`, `lib/ib/errors.rb`
- `lib/ib/messages/outgoing/old-place-order.rb`
- `lib/ib/messages/outgoing/new-place-order.rb`

Custom inflections:

- `ib` → `IB`
- `receive_fa` → `ReceiveFA`
- `tick_efp` → `TickEFP`

`lib/ib/contract.rb` reopens `IB::Contract` to add the `Subclasses` hash used by `IB::Contract.build` to return the right subclass (`IB::Stock`, `IB::Option`, etc.) based on `sec_type`.

## Models & Base Classes

- All tableless models inherit from `IB::Base` (`lib/ib/base.rb`), which uses `ActiveModel::Validations`, `ActiveModel::Serialization`, and JSON serialization.
- Properties are declared via the `prop` macro from `IB::BaseProperties` (`lib/ib/base_properties.rb`).
- `IB::Base#default_attributes` usually seeds `:created_at`.
- `Object#error` is patched globally in `lib/ib/errors.rb` with typed errors (`:standard`, `:args`, `:symbol`, `:load`, `:reader`, `:verify`). Code generally calls `error "msg", :type` instead of plain `raise`.
- `lib/class_extensions.rb` monkey-patches core classes: `String#to_bool`, `Numeric#to_bool`, `Date#to_ib`, `Time#to_ib`, `Array#as_table`, etc.

## Message System

- `lib/ib/messages.rb` defines `def_message(message_id_version, *data_map, &to_human)`.
- `message_id_version` is `[id, version]` or just `id` (version defaults to 1).
- Incoming messages live in `lib/ib/messages/incoming/` and extend `IB::Messages::Incoming::AbstractMessage`.
- Outgoing messages live in `lib/ib/messages/outgoing/` and extend `IB::Messages::Outgoing::AbstractMessage`.
- Data maps use these forms:
  - `[name, type]` — simple field
  - `[group, name, type]` — grouped field, stored as `@data[:group][:name]`
  - `[version_condition, ...]` — conditional fields based on received version
- Incoming messages are looked up at runtime via `IB::Messages::Incoming::Classes[id]`.
- TWS field decoding uses `IB::Support` refinements (`lib/ib/support.rb`) on `Array` (`read_int`, `read_decimal`, `read_string`, `read_xml`, etc.).

## Plugins

- Located in `plugins/ib/`.
- Activated through `IB::Connection#activate_plugin` (`lib/ib/plugins.rb`).
- **Naming gotcha**: underscores are converted to dashes. Use either:
  - `activate_plugin :connection_tools` → loads `plugins/ib/connection-tools.rb`
  - `activate_plugin "managed-accounts"` → loads `plugins/ib/managed-accounts.rb`
- Plugins are modules that extend `IB::Connection`; they often depend on workflow state transitions.
- `Connection` uses the `workflow` gem with states: `virgin`, `lean_mode`, `gateway_mode`, `ready`, `account_based_operations`, `account_based_orderflow`. Several plugins drive transitions (e.g. `managed-accounts`, `process-orders`).

## Test Infrastructure

- `spec/spec_helper.rb` loads `simplecov` first, then `ib-api`, then patches the socket stub, then loads mocks and factories.
- `spec/support/socket_patch.rb` replaces `IB::Socket` with `IB::SocketStub` and intercepts `Kernel.select` unless `TEST_ENV=real`.
- `spec/support/factories.rb` exposes `IB::Test::Factory` with helpers like `Factory.create(:stock, ...)`.
- `spec/spec.yml` stores connection/account/sample-stock config. Set `:account` to your paper account before integration tests.
- Shared helpers: `spec/main_helper.rb` (connection stubs, log helpers), `spec/model_helper.rb` (property/validation shared examples), `spec/account_helper.rb`, `spec/contract_helper.rb`, `spec/order_helper.rb`, `spec/combo_helper.rb`, `spec/integration_helper.rb`.

## Coverage Exclusions (`.simplecov`)

Excluded from coverage reports:

- `/spec/`, `/bin/`, `/lib/ib/version.rb`
- Legacy outgoing messages: `old-place-order.rb`, `new-place-order.rb`
- Empty file: `plugins/ib/auto-adjust.rb`
- Plugins requiring live market/TWS: `eod.rb`, `market-price.rb`, `greeks.rb`, `option-chain.rb`, `advanced-account.rb`, `probability-of-expiring.rb`

## Files to Treat as Historical / Do Not Rely On

- `.travis.yml` targets Ruby 2.6.1 and bundler 1.17.2; it is stale.
- `lib/ib/messages/outgoing/old-place-order.rb` and `new-place-order.rb` exist on disk but are ignored by Zeitwerk and SimpleCov.
- `models/ib/` is tracked and actively loaded alongside `lib/ib/`; do not assume it is dead code.

## Console & Runtime Defaults

- `bin/console` and `bin/simple` read `bin/console.yml`. If the file is missing, the YAML load will fail.
- Default connection targets in `bin/console.yml`:
  - Gateway: `localhost:4002`
  - TWS: `tws:7496`
  - Default `client_id`: `2000`
