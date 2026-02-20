# frozen_string_literal: true

require_relative 'factories/base_factory'
require_relative 'factories/contract_factory'
require_relative 'factories/order_factory'
require_relative 'factories/message_factory'

module IB
  module Test
    module Factory
      extend self

      include ContractFactory
      include OrderFactory
      include MessageFactory

      def create(type, **attributes)
        case type
        when :stock
          create_stock(**attributes)
        when :option
          create_option(**attributes)
        when :future
          create_future(**attributes)
        when :index
          create_index(**attributes)
        when :cfd
          create_cfd(**attributes)
        when :commodity
          create_commodity(**attributes)
        when :bond
          create_bond(**attributes)
        when :combo
          create_combo(**attributes)
        when :forex
          create_forex(**attributes)
        when :market_order
          create_market_order(**attributes)
        when :limit_order
          create_limit_order(**attributes)
        when :stop_order
          create_stop_order(**attributes)
        when :stop_limit_order
          create_stop_limit_order(**attributes)
        else
          raise ArgumentError, "Unknown factory type: #{type}"
        end
      end

      # Build an object without saving (for messages)
      def build(type, **attributes)
        create(type, **attributes)
      end

      # Create multiple objects
      def create_list(type, count, **attributes)
        count.times.map { create(type, **attributes) }
      end

      # Create with traits
      def create_with_traits(type, *traits, **attributes)
        traits.each do |trait|
          attributes = apply_trait(trait, attributes)
        end
        create(type, **attributes)
      end

      private

      def apply_trait(trait, attributes)
        case trait
        when :smart_exchange
          attributes.merge(exchange: 'SMART')
        when :day_order
          attributes.merge(tif: 'DAY')
        when :gtc_order
          attributes.merge(tif: 'GTC')
        when :paper_account
          attributes.merge(account: 'DU123456')
        else
          attributes
        end
      end
    end
  end
end
