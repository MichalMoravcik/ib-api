require 'spec_helper'

describe IB::Order do
  describe 'basic functionality' do
    it 'creates an order' do
      order = IB::Order.new(
        total_quantity: 100,
        limit_price: 150.0,
        order_type: :limit
      )
      expect(order).to be_a(IB::Order)
      expect(order.total_quantity).to eq(100)
      expect(order.limit_price).to eq(150.0)
    end

    it 'defaults order_type to limit' do
      order = IB::Order.new
      expect(order.order_type).to eq(:limit)
    end

    it 'defaults tif to day' do
      order = IB::Order.new
      expect(order.tif).to eq(:day)
    end
  end

  describe 'properties' do
    it 'has local_id' do
      order = IB::Order.new(local_id: 123)
      expect(order.local_id).to eq(123)
    end

    it 'has client_id' do
      order = IB::Order.new(client_id: 456)
      expect(order.client_id).to eq(456)
    end

    it 'has perm_id' do
      order = IB::Order.new(perm_id: 789)
      expect(order.perm_id).to eq(789)
    end

    it 'aliases quantity to total_quantity' do
      order = IB::Order.new(total_quantity: 100)
      expect(order.total_quantity).to eq(100)
    end
  end

  describe 'order types' do
    it 'creates market order' do
      order = IB::Order.new(order_type: :market)
      expect(order.order_type).to eq(:market)
    end

    it 'creates stop order' do
      order = IB::Order.new(order_type: :stop)
      expect(order.order_type).to eq(:stop)
    end

    it 'creates stop_limit order' do
      order = IB::Order.new(order_type: :stop_limit)
      expect(order.order_type).to eq(:stop_limit)
    end
  end

  describe 'time in force' do
    it 'defaults to day' do
      order = IB::Order.new
      expect(order.tif).to eq(:day)
    end

    it 'accepts good_til_canceled' do
      order = IB::Order.new(tif: :good_till_cancelled)
      expect(order.tif).to eq(:good_till_cancelled)
    end
  end

  describe 'complex orders' do
    it 'creates bracket order' do
      order = IB::Order.new(
        total_quantity: 100,
        limit_price: 150.0,
        parent_id: 100
      )
      expect(order.parent_id).to eq(100)
    end

    it 'creates OCA group order' do
      order = IB::Order.new(
        total_quantity: 100,
        oca_group: 'OCA_001'
      )
      expect(order.oca_group).to eq('OCA_001')
    end
  end

  describe 'serialization' do
    it 'serializes combo legs' do
      order = IB::Order.new
      bag = IB::Bag.new
      result = order.serialize_combo_legs(bag)
      expect(result).to be_an(Array)
    end

    it 'serializes main order fields' do
      order = IB::Order.new(
        total_quantity: 100,
        order_type: :limit,
        limit_price: 150.0
      )
      result = order.serialize_main_order_fields
      expect(result).to be_an(Array)
    end

    it 'serializes extended order fields' do
      order = IB::Order.new(
        tif: :good_till_cancelled,
        oca_group: 'OCA_1',
        account: 'U123',
        open_close: :open,
        origin: :customer,
        transmit: true,
        parent_id: 7
      )
      result = order.serialize_extended_order_fields
      expect(result).to eq(['GTC', 'OCA_1', 'U123', 'O', 0, nil, true, 7, false, false, nil, 0, false, false])
    end

    it 'serializes auxiliary order fields' do
      order = IB::Order.new(
        discretionary_amount: 0.5,
        good_after_time: '20240101 10:00:00',
        good_till_date: '20240101 16:00:00'
      )
      result = order.serialize_auxilery_order_fields
      expect(result.first).to eq('')
      expect(result[1]).to eq(0.5)
      expect(result[2]).to eq('20240101 10:00:00')
      expect(result[3]).to eq('20240101 16:00:00')
      expect(result.last).to be_an(Array)
    end

    it 'serializes conditions' do
      order = IB::Order.new
      expect(order.serialize_conditions).to eq([0])
    end

    it 'serializes algo fields' do
      order = IB::Order.new(algo_strategy: 'ArrivalPrice', algo_params: { max_pct_vol: 0.1 })
      result = order.serialize_algo
      expect(result.first).to eq('ArrivalPrice')
      expect(result[1]).to eq(1)
    end

    it 'returns empty algo when no strategy' do
      order = IB::Order.new
      expect(order.serialize_algo).to eq([''])
    end

    it 'serializes volatility fields when present' do
      order = IB::Order.new(volatility: 0.25)
      result = order.serialize_volatility_order_fields
      expect(result).to eq([0.25, 2])
    end

    it 'returns empty volatility fields when absent' do
      order = IB::Order.new
      expect(order.serialize_volatility_order_fields).to eq(['', ''])
    end

    it 'serializes delta neutral fields when active' do
      order = IB::Order.new(
        delta_neutral_order_type: :limit,
        delta_neutral_con_id: 123,
        delta_neutral_settling_firm: 'FIRM',
        delta_neutral_clearing_account: 'ACC'
      )
      result = order.serialize_delta_neutral_order_fields
      expect(result).to include(123, 'FIRM', 'ACC')
    end

    it 'returns empty delta neutral fields when inactive' do
      order = IB::Order.new
      expect(order.serialize_delta_neutral_order_fields).to eq(['', ''])
    end

    it 'serializes scale order fields' do
      order = IB::Order.new(
        scale_init_level_size: 10,
        scale_subs_level_size: 5,
        scale_price_increment: 1.0
      )
      result = order.serialize_scale_order_fields
      expect(result).to include(10, 5, 1.0)
    end

    it 'serializes pegged order fields for pegged_to_benchmark' do
      order = IB::Order.new(
        order_type: :pegged_to_benchmark,
        reference_contract_id: 123,
        pegged_change_amount: 0.5,
        reference_change_amount: 1.0,
        reference_exchange_id: 'SMART'
      )
      allow(order).to receive(:server_version).and_return(KNOWN_SERVERS[:min_server_ver_pegged_to_benchmark] + 1)
      result = order.serialize_pegged_order_fields
      expect(result).to eq([123, false, 0.5, 1.0, 'SMART'])
    end

    it 'returns empty pegged fields for non-benchmark orders' do
      order = IB::Order.new(order_type: :limit)
      expect(order.serialize_pegged_order_fields).to eq([])
    end

    it 'serializes soft dollar tier' do
      order = IB::Order.new(soft_dollar_tier_name: 'Name', soft_dollar_tier_value: 'Value')
      expect(order.serialize_soft_dollar_tier).to eq(['Name', 'Value'])
    end

    it 'serializes mifid fields' do
      order = IB::Order.new(
        mifid_2_decision_maker: 'DM',
        mifid_2_decision_algo: 'ALGO1',
        mifid_2_execution_maker: 'EM',
        mifid_2_execution_algo: 'ALGO2'
      )
      allow(order).to receive(:server_version).and_return(KNOWN_SERVERS[:min_server_ver_mifid_execution] + 1)
      result = order.serialize_mifid_order_fields
      expect(result).to eq([['DM', 'ALGO1'], ['EM', 'ALGO2']])
    end

    it 'returns empty peg best and mid fields by default' do
      order = IB::Order.new(contract: IB::Stock.new(symbol: 'AAPL'))
      allow(order).to receive(:server_version).and_return(KNOWN_SERVERS[:min_server_ver_pegbest_pegmid_offsets] + 1)
      expect(order.serialize_peg_best_and_mid).to eq([])
    end

    it 'serializes peg best and mid for IBKRATS contract' do
      order = IB::Order.new(
        order_type: :pegged_to_best,
        contract: IB::Stock.new(symbol: 'AAPL', exchange: 'IBKRATS'),
        min_trade_qty: 10,
        min_compete_size: 5,
        compete_against_best_offset: 0.01
      )
      allow(order).to receive(:server_version).and_return(KNOWN_SERVERS[:min_server_ver_pegbest_pegmid_offsets] + 1)
      result = order.serialize_peg_best_and_mid
      expect(result).to include(10, 5, 0.01)
    end

    it 'sends mid offsets for pegged_to_midpoint' do
      order = IB::Order.new(
        order_type: :pegged_to_midpoint,
        contract: IB::Stock.new(symbol: 'AAPL'),
        mid_offset_at_whole: 0.05,
        mid_offset_at_half: 0.025
      )
      allow(order).to receive(:server_version).and_return(KNOWN_SERVERS[:min_server_ver_pegbest_pegmid_offsets] + 1)
      result = order.serialize_peg_best_and_mid
      expect(result).to include(0.05, 0.025)
    end

    it 'serializes scale order fields with extended parameters' do
      order = IB::Order.new(
        scale_init_level_size: 10,
        scale_subs_level_size: 5,
        scale_price_increment: 1.0,
        scale_price_adjust_value: 0.5,
        scale_price_adjust_interval: 2,
        scale_profit_offset: 0.25,
        scale_auto_reset: true,
        scale_init_position: 1,
        scale_init_fill_qty: 10,
        scale_random_percent: false
      )
      result = order.serialize_scale_order_fields
      expect(result.flatten).to include(10, 5, 1.0, 0.5, 2, 0.25, true, 1, 10, false)
    end

    it 'serializes advisory order fields' do
      order = IB::Order.new(fa_group: 'Group', fa_method: 'Method', fa_percentage: '10', fa_profile: 'Profile')
      allow(order).to receive(:server_version).and_return(KNOWN_SERVERS[:min_server_ver_fa_profile_desupport] - 1)
      expect(order.serialize_advisory_order_fields).to eq(['Group', 'Method', '10', 'Profile'])
    end

    it 'drops fa_profile in newer server versions' do
      order = IB::Order.new(fa_group: 'Group', fa_method: 'Method', fa_percentage: '10', fa_profile: 'Profile')
      allow(order).to receive(:server_version).and_return(KNOWN_SERVERS[:min_server_ver_fa_profile_desupport] + 1)
      expect(order.serialize_advisory_order_fields).to eq(['Group', 'Method', '10'])
    end

    it 'serializes short and short_exempt sides' do
      order = IB::Order.new(total_quantity: 100, order_type: :limit, side: :short)
      expect(order.serialize_main_order_fields.first).to eq('SSHORT')
      order2 = IB::Order.new(total_quantity: 100, order_type: :limit, side: :short_exempt)
      expect(order2.serialize_main_order_fields.first).to eq('SSHORTX')
    end

    it 'serializes conditions with ignore rth and cancel order flags' do
      condition = IB::PriceCondition.new(
        operator: '>=',
        price: 150.0,
        contract: IB::Stock.new(symbol: 'AAPL', con_id: 123, exchange: 'SMART'),
        trigger_method: :last
      )
      order = IB::Order.new(
        conditions: [condition],
        conditions_ignore_rth: true,
        conditions_cancel_order: true
      )
      result = order.serialize_conditions
      expect(result.size).to be > 1
      expect(result.last(2)).to eq([true, true])
    end

    it 'serializes rabbit format' do
      order = IB::Order.new(contract: IB::Stock.new(symbol: 'AAPL'))
      result = order.serialize_rabbit
      expect(result).to have_key('Contract')
      expect(result).to have_key('Order')
      expect(result).to have_key('OrderState')
    end

    it 'renders table header and row' do
      order = IB::Order.new(
        total_quantity: 100,
        limit_price: 150.0,
        contract: IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD')
      )
      expect(order.table_header).to be_an(Array)
      expect(order.table_row).to be_an(Array)
    end
  end

  describe 'state delegation' do
    it 'delegates status to order_state' do
      order = IB::Order.new
      expect(order.status).to eq('New')
    end

    it 'delegates filled and remaining' do
      order = IB::Order.new
      expect(order.filled).to eq(0)
      expect(order.remaining).to eq(0)
    end

    it 'assigns order_state by symbol' do
      order = IB::Order.new
      order.order_state = :submitted
      expect(order.order_state.status).to eq('submitted')
    end

    it 'delegates new? and submitted? predicates' do
      order = IB::Order.new
      expect(order.new?).to be true
      expect(order.submitted?).to be_falsey
    end

    it 'delegates margin accessors' do
      order = IB::Order.new
      order.order_state = IB::OrderState.new(
        status: 'Submitted',
        init_margin_change: 100.0,
        maint_margin_change: 90.0,
        equity_with_loan_change: 1000.0
      )
      expect(order.init_margin).to eq(100.0)
      expect(order.maint_margin).to eq(90.0)
      expect(order.equity_with_loan).to eq(1000.0)
    end
  end

  describe 'comparison' do
    it 'considers orders with same local_id equal' do
      a = IB::Order.new(local_id: 1, client_id: 100)
      b = IB::Order.new(local_id: 1, client_id: 100)
      expect(a).to eq(b)
    end

    it 'distinguishes orders with different local_id' do
      a = IB::Order.new(local_id: 1)
      b = IB::Order.new(local_id: 2)
      expect(a).not_to eq(b)
    end
  end

  describe 'human formatting' do
    it 'renders to_s' do
      order = IB::Order.new(total_quantity: 100, limit_price: 150.0)
      expect(order.to_s).to include('Order')
    end

    it 'renders to_human' do
      order = IB::Order.new(total_quantity: 100, limit_price: 150.0)
      expect(order.to_human).to include('LMT')
    end
  end
end
