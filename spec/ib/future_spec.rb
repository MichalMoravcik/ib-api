require 'spec_helper'

describe IB::Future do
  describe 'validations' do
    it 'requires sec_type future' do
      expect(IB::Future.new).to be_valid
      future = IB::Future.new(sec_type: :stock)
      expect(future).not_to be_valid
    end
  end

  describe 'defaults' do
    it 'defaults sec_type to future and currency to USD' do
      future = IB::Future.new
      expect(future.sec_type).to eq(:future)
      expect(future.currency).to eq('USD')
    end
  end

  describe '#to_human' do
    it 'includes symbol and expiry' do
      future = IB::Future.new(symbol: 'ES', expiry: '20251218')
      expect(future.to_human).to include('ES')
      expect(future.to_human).to include('20251218')
    end
  end

  describe '.next_expiry' do
    it 'returns next quarterly expiry as string' do
      result = IB::Future.next_expiry(Date.new(2025, 1, 15))
      expect(result).to match(/\d{8}/)
      expect(result).to start_with('2025')
    end

    it 'rolls to next year in December' do
      result = IB::Future.next_expiry(Date.new(2025, 12, 20))
      expect(result[0..3]).to eq('2026')
    end

    it 'uses verify plugin when available' do
      future = IB::Future.new(symbol: 'ES', exchange: 'GLOBEX')
      conn = instance_double(IB::Connection, plugins: ['verify'])
      allow(IB::Connection).to receive(:current).and_return(conn)
      target = IB::Future.next_expiry(Date.new(2025, 1, 15))
      verified = IB::Future.new(symbol: 'ES', expiry: target, last_trading_day: target)
      allow(future).to receive(:verify).and_return([verified])
      result = future.next_expiry(Date.new(2025, 1, 15))
      expect(result).to eq(verified)
    end

    it 'falls back to class method without verify plugin' do
      future = IB::Future.new(symbol: 'ES', exchange: 'GLOBEX')
      conn = instance_double(IB::Connection, plugins: [])
      allow(IB::Connection).to receive(:current).and_return(conn)
      result = future.next_expiry(Date.new(2025, 1, 15))
      expect(result).to match(/\d{8}/)
    end
  end
end
