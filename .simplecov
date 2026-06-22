# frozen_string_literal: true

require 'simplecov'

SimpleCov.start do
  # Enable branch coverage for more detailed coverage analysis
  enable_coverage :branch

  # Exclude test helpers and specs from coverage — these are not production code
  add_filter '/spec/'

  # Exclude CLI entry points — exercised separately via bin/ scripts
  add_filter '/bin/'

  # Exclude version file — single constant definition, not testable in isolation
  add_filter '/lib/ib/version.rb'

  # Exclude legacy outgoing message files — not loaded by Zeitwerk
  add_filter '/lib/ib/messages/outgoing/old-place-order.rb'
  add_filter '/lib/ib/messages/outgoing/new-place-order.rb'

  # Exclude empty file with no production code
  add_filter '/plugins/ib/auto-adjust.rb'

  # Exclude plugins that require live market data / TWS connection
  # These cannot be meaningfully tested without a real TWS instance
  add_filter '/plugins/ib/eod.rb'
  add_filter '/plugins/ib/market-price.rb'
  add_filter '/plugins/ib/greeks.rb'
  add_filter '/plugins/ib/option-chain.rb'
  add_filter '/plugins/ib/advanced-account.rb'
  add_filter '/plugins/ib/probability-of-expiring.rb'
end