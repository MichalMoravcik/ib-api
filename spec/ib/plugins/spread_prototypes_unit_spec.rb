require 'spec_helper'

# Save/restore Connection.current because spread-prototypes activates
# sub-plugins via IB::Connection.current during file load.
_original_connection = IB::Connection.current
IB::Connection.current = IB::Connection.new.tap { |c| c.instance_variable_set(:@socket, IB::SocketStub.new) }
require_relative '../../../plugins/ib/spread-prototypes'
IB::Connection.current = _original_connection

# Unit tests for spread prototype plugins using stubbed verify.
describe 'IB::Spread prototypes (unit)' do
  let(:call_option) do
    IB::Option.new(
      symbol: 'AAPL',
      expiry: '20241220',
      right: :call,
      strike: 150.0,
      exchange: 'SMART',
      currency: 'USD',
      con_id: 1001,
      last_trading_day: '2024-12-20',
      trading_class: 'AAPL'
    )
  end

  let(:put_option) do
    IB::Option.new(
      symbol: 'AAPL',
      expiry: '20241220',
      right: :put,
      strike: 150.0,
      exchange: 'SMART',
      currency: 'USD',
      con_id: 1002,
      last_trading_day: '2024-12-20',
      trading_class: 'AAPL'
    )
  end

  let(:stock) { IB::Stock.new(symbol: 'AAPL', exchange: 'SMART', currency: 'USD', con_id: 2001) }

  let(:future) do
    IB::Future.new(
      symbol: 'ES',
      expiry: '20241220',
      exchange: 'GLOBEX',
      currency: 'USD',
      con_id: 3001
    )
  end

  let(:future_option) do
    IB::Option.new(
      symbol: 'ES',
      expiry: '20241220',
      right: :put,
      strike: 4500.0,
      exchange: 'GLOBEX',
      currency: 'USD',
      con_id: 4001,
      sec_type: :futures_option,
      trading_class: 'ES'
    )
  end

  before do
    # Default stubs - can be overridden in specific tests
    allow(call_option).to receive(:verify).and_return([call_option])
    allow(put_option).to receive(:verify).and_return([put_option])
    allow(stock).to receive(:verify).and_return([stock])
    allow(future).to receive(:verify).and_return([future])
    allow(future_option).to receive(:verify).and_return([future_option])
  end

  after do
    IB::Connection.current = nil
  end

  describe IB::Calendar do
    it 'returns parameters' do
      expect(IB::Calendar.parameters).to include('Required')
    end

    it 'returns defaults' do
      expect(IB::Calendar.defaults).to include(right: :put)
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg call_option, action: :buy
      spread.add_leg put_option, action: :sell
      expect(IB::Calendar.the_description(spread)).to include('Calendar')
    end

    describe '.fabricate' do
      context 'with valid option master' do
        before do
          merged_option = call_option.merge(expiry: '20250320')
          allow(call_option).to receive(:verify).and_return([call_option])
          allow(call_option).to receive(:merge).and_return(merged_option)
          allow(merged_option).to receive(:verify).and_return([merged_option])
          allow(merged_option).to receive(:essential).and_return(merged_option)
          allow(call_option).to receive(:essential).and_return(call_option)
          allow(call_option).to receive(:exchange).and_return('SMART')
          allow(call_option).to receive(:symbol).and_return('AAPL')
          allow(call_option).to receive(:currency).and_return('USD')
          allow(IB::Spread).to receive(:transform_distance).and_return('20250320')
        end

        it 'creates a calendar spread from master option' do
          spread = IB::Calendar.fabricate(call_option, '20250320')
          expect(spread).to be_an(IB::Spread)
          expect(spread.legs.size).to eq(2)
          expect(spread.symbol).to eq('AAPL')
        end

        it 'sets buy action on first leg and sell on second leg' do
          spread = IB::Calendar.fabricate(call_option, '20250320')
          actions = spread.combo_legs.map(&:action)
          expect(actions).to include(:buy)
          expect(actions).to include(:sell)
        end
      end

      context 'with future as master' do
        before do
          merged_future = future.merge(expiry: '20250320')
          allow(future).to receive(:verify).and_return([future])
          allow(future).to receive(:merge).and_return(merged_future)
          allow(merged_future).to receive(:verify).and_return([merged_future])
          allow(merged_future).to receive(:essential).and_return(merged_future)
          allow(future).to receive(:essential).and_return(future)
          allow(future).to receive(:exchange).and_return('GLOBEX')
          allow(future).to receive(:symbol).and_return('ES')
          allow(future).to receive(:currency).and_return('USD')
          allow(future).to receive(:sec_type).and_return(:future)
          allow(IB::Spread).to receive(:transform_distance).and_return('20250320')
        end

        it 'accepts future as master' do
          spread = IB::Calendar.fabricate(future, '20250320')
          expect(spread).to be_an(IB::Spread)
        end
      end

      context 'with invalid master type' do
        it 'raises error for non-option/future master' do
          expect {
            IB::Calendar.fabricate(stock, '20250320')
          }.to raise_error(IB::Error, /Argument must be a IB::Future or IB::Option/)
        end
      end

      context 'with failed verification' do
        before do
          allow(call_option).to receive(:verify).and_return([])
        end

        it 'raises error when verification fails' do
          expect {
            IB::Calendar.fabricate(call_option, '20250320')
          }.to raise_error(IB::Error, /Verification failed/)
        end
      end
    end
  end

  describe IB::Butterfly do
    it 'returns parameters' do
      expect(IB::Butterfly.parameters).to include('Required')
    end

    it 'returns defaults' do
      expect(IB::Butterfly.defaults).to include(right: :put)
    end

    it 'returns requirements' do
      expect(IB::Butterfly.requirements).to include(back: 'the strike of the lower bougth option')
      expect(IB::Butterfly.requirements).to include(front: 'the strike of the upper bougth option')
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      [140, 150, 160].each { |strike| spread.add_leg call_option.merge(strike: strike) }
      expect(IB::Butterfly.the_description(spread)).to include('Butterfly')
    end

    describe '.fabricate' do
      context 'with non-option master' do
        it 'raises error when master is not an option' do
          expect {
            IB::Butterfly.fabricate(stock, front: 140, back: 160)
          }.to raise_error(IB::Error, /fabrication is based on a master option/)
        end
      end

      context 'with empty verification result' do
        before do
          allow(call_option).to receive(:verify).and_return([])
        end

        it 'raises error when verification returns empty' do
          expect {
            IB::Butterfly.fabricate(call_option, front: 140, back: 160)
          }.to raise_error(IB::Error, /Invalid Parameters/)
        end
      end

      context 'with ambiguous contract specification' do
        before do
          call_option2 = call_option.merge(trading_class: 'AAPL2')
          allow(call_option).to receive(:verify).and_return([call_option, call_option2])
          allow(call_option).to receive(:trading_class).and_return('AAPL')
          allow(call_option2).to receive(:trading_class).and_return('AAPL2')
          allow(call_option2).to receive(:to_human).and_return('<Option: AAPL>')
        end

        it 'raises error when multiple contracts found with different trading classes' do
          expect {
            IB::Butterfly.fabricate(call_option, front: 140, back: 160)
          }.to raise_error(IB::Error)
        end
      end
    end

    describe '.build' do
      before do
        allow(IB::Future).to receive(:next_expiry).and_return('20241220')
      end

      context 'with non-option underlying' do
        before do
          merged_option = call_option.merge(strike: 150)
          allow(IB::Option).to receive(:new).and_return(call_option)
          allow(call_option).to receive(:verify).and_return([call_option])
          allow(call_option).to receive(:essential).and_return(call_option)
          allow(call_option).to receive(:attributes).and_return(call_option.attributes)
          allow(call_option).to receive(:merge).and_return(merged_option)
          allow(merged_option).to receive(:verify).and_return([merged_option])
          allow(merged_option).to receive(:essential).and_return(merged_option)
        end

        it 'creates butterfly from non-option underlying' do
          spread = IB::Butterfly.build(from: stock, front: 140, back: 160, strike: 150, right: :put)
          expect(spread).to be_an(IB::Spread)
        end
      end
    end
  end

  describe IB::Vertical do
    it 'returns parameters' do
      expect(IB::Vertical.parameters).to include('Required')
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg call_option, action: :buy
      spread.add_leg put_option.merge(strike: 155), action: :sell
      expect(IB::Vertical.the_description(spread)).to include('Vertical')
    end

    describe '.fabricate' do
      context 'with neither buy nor sell specified' do
        it 'raises error when both buy and sell are zero' do
          expect {
            IB::Vertical.fabricate(call_option, buy: 0, sell: 0)
          }.to raise_error(IB::Error, /Either :buy or :sell must be specified/)
        end
      end

      context 'with non-option master' do
        it 'raises error when master is not an option' do
          expect {
            IB::Vertical.fabricate(stock, buy: 155)
          }.to raise_error(IB::Error, /Argument must be an option/)
        end
      end

      context 'with invalid sec_type' do
        it 'raises error when master is not an option/futures_option' do
          expect {
            IB::Vertical.fabricate(stock, buy: 155)
          }.to raise_error(IB::Error, /Argument must be an option/)
        end
      end
    end

    describe '.build' do
      before do
        mock_detail = double('contract_detail', under_con_id: 2001)
        allow(call_option).to receive(:contract_detail).and_return(mock_detail)
        allow(call_option).to receive(:verify).and_return([call_option])
        allow(call_option).to receive(:right).and_return(:put)
        allow(call_option).to receive(:strike).and_return(150.0)
        allow(call_option).to receive(:expiry).and_return('20241220')
        allow(call_option).to receive(:trading_class).and_return('AAPL')
        allow(call_option).to receive(:multiplier).and_return(100)
        allow(call_option).to receive(:is_a?).with(IB::Option).and_return(true)
        allow(call_option).to receive(:merge).and_return(call_option)
        allow(stock).to receive(:verify).and_return([stock])
        allow(stock).to receive(:essential).and_return(stock)
        allow(IB::Contract).to receive(:new).and_return(stock)
        allow(IB::Option).to receive(:new).and_return(call_option)
        allow(IB::Future).to receive(:next_expiry).and_return('20241220')
      end

      context 'with missing buy and sell' do
        before do
          allow(stock).to receive(:is_a?).with(IB::Option).and_return(false)
        end

        it 'raises error when buy and sell are not specified' do
          expect {
            IB::Vertical.build(from: stock)
          }.to raise_error(IB::Error, /Specification of :buy and :sell necessary/)
        end
      end
    end
  end

  describe IB::Strangle do
    it 'returns parameters' do
      expect(IB::Strangle.parameters).to include('Required')
    end

    it 'returns requirements' do
      expect(IB::Strangle.requirements).to include(p: 'the strike of the put option')
      expect(IB::Strangle.requirements).to include(c: 'the strike of the call option')
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg put_option.merge(strike: 145)
      spread.add_leg call_option.merge(strike: 155)
      expect(IB::Strangle.the_description(spread)).to include('Strangle')
    end

    describe '.fabricate' do
      context 'with valid option and distance' do
        before do
          put_at_140 = put_option.merge(strike: 140)
          call_at_160 = call_option.merge(strike: 160, right: :call)
          allow(call_option).to receive(:verify).and_return([call_option])
          allow(call_option).to receive(:essential).and_return(call_option)
          allow(call_option).to receive(:merge).and_return(call_option)
          allow(call_option).to receive(:strike).and_return(150.0)
          allow(call_option).to receive(:right).and_return(:put)
          allow(call_option).to receive(:sec_type).and_return(:option)
          allow(call_option).to receive(:local_symbol).and_return('')
          allow(call_option).to receive(:con_id).and_return(0)
          allow(put_option).to receive(:merge).and_return(put_at_140)
          allow(put_at_140).to receive(:verify).and_return([put_at_140])
          allow(call_option).to receive(:merge).with(hash_including(right: :call, strike: 160.0)).and_return(call_at_160)
          allow(call_at_160).to receive(:verify).and_return([call_at_160])
        end

        it 'creates a strangle spread' do
          spread = IB::Strangle.fabricate(call_option, 10)
          expect(spread).to be_an(IB::Spread)
          expect(spread.legs.size).to eq(2)
        end
      end

      context 'with non-option master' do
        it 'raises error when master is not an option' do
          expect {
            IB::Strangle.fabricate(stock, 10)
          }.to raise_error(IB::Error, /Argument must be an option/)
        end
      end
    end
  end

  describe IB::Straddle do
    it 'returns parameters' do
      expect(IB::Straddle.parameters).to include('Required')
    end

    it 'returns requirements' do
      expect(IB::Straddle.requirements).to include(strike: "the strike of both options")
      expect(IB::Straddle.requirements).to include(expiry: "Expiry expressed as »yyyymm(dd)« (String or Integer)")
    end

    it 'formats a description' do
      spread = IB::Spread.new(symbol: 'AAPL', currency: 'USD', exchange: 'SMART')
      spread.add_leg put_option
      spread.add_leg call_option
      expect(IB::Straddle.the_description(spread)).to include('Straddle')
    end

    describe '.fabricate' do
      context 'with non-option master' do
        it 'raises error when master is not an option' do
          expect {
            IB::Straddle.fabricate(stock)
          }.to raise_error(IB::Error, /Argument must be a IB::Option/)
        end
      end

      context 'with futures_option master' do
        before do
          fop_call = future_option.merge(right: :call, local_symbol: '')
          allow(future_option).to receive(:verify).and_return([future_option])
          allow(future_option).to receive(:essential).and_return(future_option)
          allow(future_option).to receive(:merge).and_return(future_option)
          allow(future_option).to receive(:right).and_return(:put)
          allow(future_option).to receive(:sec_type).and_return(:futures_option)
          allow(fop_call).to receive(:verify).and_return([fop_call])
          allow(future_option).to receive(:merge).with(right: :call, local_symbol: '').and_return(fop_call)
        end

        it 'accepts futures_option as master' do
          spread = IB::Straddle.fabricate(future_option)
          expect(spread).to be_an(IB::Spread)
        end
      end
    end
  end
end
