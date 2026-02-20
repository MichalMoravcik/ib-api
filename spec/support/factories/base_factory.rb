# frozen_string_literal: true

module IB
  module Test
    module BaseFactory
      def defaults_for(type)
        case type
        when :stock
          { symbol: 'AAPL', sec_type: 'STK', exchange: 'SMART', currency: 'USD' }
        when :option
          { symbol: 'AAPL', sec_type: 'OPT', exchange: 'SMART', currency: 'USD', strike: 150.0, expiry: '20251220',
            right: 'C' }
        when :future
          { symbol: 'ES', sec_type: 'FUT', exchange: 'GLOBEX', currency: 'USD', expiry: '202512' }
        when :index
          { symbol: 'SPX', sec_type: 'IND', exchange: 'CBOE', currency: 'USD' }
        when :cfd
          { symbol: 'AAPL', sec_type: 'CFD', exchange: 'SMART', currency: 'USD' }
        when :commodity
          { symbol: 'XAUUSD', sec_type: 'CMDTY', exchange: 'SMART', currency: 'USD' }
        when :bond
          { symbol: 'US30Y', sec_type: 'BOND', exchange: 'NYSE', currency: 'USD' }
        when :forex
          { symbol: 'EUR', sec_type: 'CASH', exchange: 'IDEALPRO', currency: 'USD' }
        else
          {}
        end
      end

      def attributes_for(type, **user_attrs)
        defaults_for(type).merge(user_attrs)
      end

      def validate_attributes!(type, attrs, *required)
        missing = required.select { |attr| attrs[attr].nil? || attrs[attr].to_s.empty? }
        raise ArgumentError, "Missing required attributes for #{type}: #{missing.join(', ')}" unless missing.empty?
      end
    end
  end
end
