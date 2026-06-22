require 'spec_helper'

describe IB::OrderState do
  let(:state) do
    IB::OrderState.new(
      status: 'Submitted',
      local_id: 1,
      perm_id: 123,
      client_id: 456,
      filled: 10,
      remaining: 90,
      last_fill_price: 150.0,
      average_fill_price: 149.5,
      init_margin_after: 1000.0,
      maint_margin_after: 900.0,
      equity_with_loan_after: 5000.0,
      commission: 1.25,
      why_held: 'locate',
      warning_text: 'test warning'
    )
  end

  describe 'validations' do
    it 'is valid with status' do
      expect(state).to be_valid
    end

    it 'is invalid without status' do
      state.status = ''
      expect(state).not_to be_valid
    end

    it 'validates numericality of price fields' do
      state.last_fill_price = 'not-a-number'
      expect(state).not_to be_valid
    end

    it 'validates integer-only ids' do
      state.local_id = 1.5
      expect(state).not_to be_valid
    end
  end

  describe '.valid_status?' do
    it 'returns true for known statuses' do
      expect(IB::OrderState.valid_status?('Filled')).to be true
    end

    it 'returns false for unknown statuses' do
      expect(IB::OrderState.valid_status?('Random')).to be false
    end
  end

  describe 'state predicates' do
    it 'is new with empty status' do
      expect(IB::OrderState.new.new?).to be true
    end

    it 'is submitted' do
      expect(state.submitted?).to be_truthy
    end

    it 'is pending' do
      expect(state.pending?).to be_truthy
    end

    it 'is inactive when new' do
      expect(IB::OrderState.new.inactive?).to be true
    end

    it 'is active when filled' do
      filled = IB::OrderState.new(status: 'Filled', remaining: 0)
      expect(filled.active?).to be true
      expect(filled.complete_fill?).to be true
    end
  end

  describe '#==' do
    it 'matches identical states' do
      other = IB::OrderState.new(
        status: 'Submitted',
        local_id: 1,
        perm_id: 123,
        client_id: 456,
        filled: 10,
        remaining: 90,
        last_fill_price: 150.0,
        average_fill_price: 149.5,
        init_margin_after: 1000.0,
        maint_margin_after: 900.0,
        equity_with_loan_after: 5000.0,
        commission: 1.25,
        why_held: 'locate',
        warning_text: 'test warning'
      )
      expect(state).to eq(other)
    end

    it 'differs when status changes' do
      other = IB::OrderState.new(
        status: 'Filled',
        local_id: 1,
        perm_id: 123,
        client_id: 456
      )
      expect(state).not_to eq(other)
    end
  end

  describe '#to_human' do
    it 'includes key fields' do
      human = state.to_human
      expect(human).to include('Submitted')
      expect(human).to include('1')
      expect(human).to include('10/90')
    end
  end

  describe '#forcast' do
    it 'returns margin and commission hash' do
      expect(state.forcast).to include(
        init_margin: 1000.0,
        commission: 1.25,
        warning: 'test warning'
      )
    end
  end
end
