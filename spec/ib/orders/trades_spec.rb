require 'order_helper'

# *notice*
#  The tests below pass only if no open or pending order is present

describe 'Trades', connected: true, integration: true, slow: true do
  before(:all) do
    establish_connection
    ib = IB::Connection.current
    ib.activate_plugin :symbols, :order_prototypes
  end

  context 'Trading Forex', if: :forex_trading_hours, focus: true do
    before(:all) do
      ib = IB::Connection.current
      @initial_order_id = ib.next_local_id
    end

    after(:all) do
      remove_open_orders
      close_connection
    end

    let(:contract) { IB::Symbols::Forex[:eurusd] } # referenced by shared examples
    %i[buy sell].each_with_index do |the_action, count|
      context "Placing #{the_action.to_s.upcase} order" do
        # referenced by shared examples
        let(:order) do
          IB::Market.order(size: 20_000, action: the_action, account: ACCOUNT)
        end
        before(:all) do
          ib = IB::Connection.current
          ib.clear_received

          # Use direct placement instead of place_the_order helper
          the_contract = IB::Symbols::Forex.eurusd
          the_contract.market_price

          the_order = IB::Market.order(size: 20_000,
                                       action: the_action,
                                       account: ACCOUNT)
          @local_id_placed = ib.place_order(the_order, the_contract)
          ib.wait_for :ExecutionData, 5

          open_order = ib.received[:OpenOrder].last.order
          @initial_order_id = open_order.local_id

          puts 'open Order'
          puts open_order.to_human
          ib.wait_for :Execution
        end

        after(:all) do
          clean_connection # Clear logs and message collector
          #     IB::Connection.current.cancel_order @local_id_placed # Just in case...
        end

        context IB::Connection do
          subject { IB::Connection.current }
          it { expect(subject.received[:OpenOrder]).to have_at_least(1).open_order_message }
          it { expect(subject.received[:OrderStatus]).to have_at_least(1).status_message }
          it { expect(subject.received[:ExecutionData]).to have_exactly(1).execution_data }
          it { expect(subject.received[:CommissionReport]).to have_exactly(1).report }
        end

        context IB::Messages::Incoming::OpenOrder do
          subject { IB::Connection.current.received[:OpenOrder].first }
          it_behaves_like 'OpenOrder message'
        end

        context IB::Order do
          subject { IB::Connection.current.received[:OpenOrder].last.order }
          #       it{ is_expected.to eql @order  }  uncomment to display the difference between the
          #                                 order send to the tws and the response after filling
          it_behaves_like 'Placed Order'
          it_behaves_like 'Filled Order'
        end

        context IB::Messages::Incoming::ExecutionData do
          subject { IB::Connection.current.received[:ExecutionData].last }
          it_behaves_like 'Proper Execution Record', the_action
        end

        context IB::Messages::Incoming::CommissionReport do
          subject { IB::Connection.current.received[:CommissionReport].last }
          it_behaves_like 'Valid CommissionReport', count
        end
      end # Placing
    end # each

    context 'Request executions' do
      before(:all) do
        ib = IB::Connection.current
        @request_id = ib.send_message :RequestExecutions,
                                      client_id: OPTS[:connection][:client_id],
                                      account: OPTS[:connection][:account],
                                      time: (Time.now.utc - 10).to_ib # Time zone problems possible
        ib.wait_for :ExecutionData, 3 # sec
      end

      after(:all) { clean_connection }

      it 'does not receive Order-related messages' do
        puts 'time'
        puts (Time.now.utc - 10).to_ib
        expect(IB::Connection.current.received[:OpenOrder]).to be_empty
        expect(IB::Connection.current.received[:OrderStatus]).to be_empty
      end

      it 'receives ExecutionData messages' do
        expect(IB::Connection.current.received[:ExecutionData]).to have_at_least(1).execution_data
      end

      it 'also receives Commission Reports' do
        expect(IB::Connection.current.received[:CommissionReport]).to have_at_least(2).reports
      end
    end # Request executions
  end # Forex order
end # Trades

__END__

