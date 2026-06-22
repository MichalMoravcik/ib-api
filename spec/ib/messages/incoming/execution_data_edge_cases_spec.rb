require 'main_helper'

# Edge-case tests for ExecutionData message

RSpec.describe IB::Messages::Incoming::ExecutionData do
  describe 'basic parsing' do
    subject do
      described_class.new([
        0,          # version
        1,          # request_id
        4,          # local_id
        0,          # con_id
        'STK',      # sec_type
        '',         # expiry
        0.0,        # strike
        '',         # right
        '',         # multiplier
        'SMART',    # exchange
        'USD',      # currency
        'AAPL',     # symbol
        'AAPL',     # local_symbol
        '',         # trading_class
        '12345',    # exec_id
        '20230101-12:34:56', # time
        'DU123456', # account_name
        'NYSE',     # exchange
        'BOT',      # side
        100,        # quantity
        150.00,     # price
        999,        # perm_id
        1111,       # client_id
        0,          # liquidation
        50,         # cumulative_quantity
        149.50,     # average_price
        '',         # order_ref
        '',         # ev_rule
        0.0,        # ev_multiplier
        '',         # model_code
        0           # last_liquidity
      ])
    end

    it 'parses request_id correctly' do
      expect(subject.request_id).to eq 1
    end

    it 'builds contract correctly' do
      expect(subject.contract).to be_a(IB::Contract)
      expect(subject.contract.symbol).to eq 'AAPL'
    end

    it 'builds execution correctly' do
      expect(subject.execution).to be_a(IB::Execution)
      expect(subject.execution.exec_id).to eq '12345'
    end
  end

  describe 'execution fields' do
    subject do
      described_class.new([
        0, '1', '4', '0', 'STK', '', '0.0', '', '', 'SMART', 'USD', 'AAPL', 'AAPL', '',
        'exec-123', '20230101-14:30:00', 'DU999', 'ISLAND', 'SLD', '200', '151.00',
        '555', '2222', '1', '100', '150.00', 'ref-001', '', '1.0', 'model-A', '2'
      ])
    end

    it 'parses all execution fields correctly' do
      exec = subject.execution
      expect(exec.exec_id).to eq 'exec-123'
      expect(exec.side).to eq 'SLD'
      expect(exec.quantity).to eq 200
      expect(exec.price).to eq 151.00
      expect(exec.perm_id).to eq 555
      expect(exec.last_liquidity).to eq 2
    end
  end

  describe 'to_human' do
    subject do
      described_class.new([
        0, '1', '4', '0', 'STK', '', '0.0', '', '', 'SMART', 'USD', 'MSFT', 'MSFT', '',
        'exec-456', '20230101-15:00:00', 'DU789', 'NASDAQ', 'BUY', '50', '250.00',
        '777', '3333', '0', '25', '249.00', '', '', '0.0', '', '0'
      ])
    end

    it 'includes contract and execution info' do
      human = subject.to_human
      expect(human).to include('MSFT')
      expect(human).to include('ExecutionData')
    end
  end
end
