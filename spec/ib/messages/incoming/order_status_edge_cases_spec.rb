require 'order_helper'

# Edge-case tests for OrderStatus message

RSpec.describe IB::Messages::Incoming::OrderStatus do
  describe 'with market_cap_price' do
    subject do
      described_class.new([
        '4',         # version (not used)
        '1313',      # local_id
        'Submitted', # status
        '0',         # filled
        '100',       # remaining
        '0',         # average_fill_price
        '172323928', # perm_id
        '0',         # parent_id
        '0',         # last_fill_price
        '1111',      # client_id
        '',          # why_held
        '5000000.0'  # market_cap_price
      ])
    end

    it 'parses market_cap_price correctly' do
      expect(subject.order_state.market_cap_price).to eq 5000000.0
    end

    it 'accesses market_cap_price via order_state' do
      os = subject.order_state
      expect(os.market_cap_price).to be_a(BigDecimal)
    end
  end

  describe 'without market_cap_price (older message format)' do
    subject do
      described_class.new([
        '4',         # version
        '1313',      # local_id
        'Submitted', # status
        '0',         # filled
        '100',       # remaining
        '0',         # average_fill_price
        '172323928', # perm_id
        '0',         # parent_id
        '0',         # last_fill_price
        '1111',      # client_id
        ''           # why_held (no market_cap_price)
      ])
    end

    it 'still parses correctly without market_cap_price' do
      expect(subject.local_id).to eq 1313
      expect(subject.status).to eq 'Submitted'
    end
  end

  describe 'various status values' do
    statuses = %w[PendingSubmit PendingCancel PreSubmitted Submitted
                  Cancelled ApiCancelled Filled Inactive]

    statuses.each do |status|
      it "parses status '#{status}' correctly" do
        msg = described_class.new([
          '0', status, '0', '100', '0', '0', '0', '0', '0', '1111', '', '0'
        ])
        expect(msg.status).to eq status
      end
    end
  end

  describe 'decimal fields' do
    it 'handles decimal filled quantity' do
      msg = described_class.new([
        '0', '4', 'Filled', '50.5', '49.5', '100.25', '0', '0', '99.50', '1111', '', '0'
      ])
      expect(msg.order_state.filled).to eq 50.5
    end

    it 'handles decimal remaining quantity' do
      msg = described_class.new([
        '0', '4', 'Submitted', '50', '49.75', '100.00', '0', '0', '0', '1111', '', '0'
      ])
      expect(msg.order_state.remaining).to eq 49.75
    end
  end
end
