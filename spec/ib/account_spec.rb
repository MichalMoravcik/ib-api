require 'spec_helper'

describe IB::Account do
  let(:account) { IB::Account.new(account: 'U12345', type: 'User', alias: 'main') }

  describe 'validations' do
    it 'is valid with proper account format' do
      expect(account).to be_valid
    end

    it 'is invalid with bad account format' do
      account.account = 'bad'
      expect(account).not_to be_valid
    end

    it 'accepts demo account prefix' do
      account.account = 'DU12345'
      expect(account).to be_valid
    end

    it 'accepts advisor type' do
      account.type = 'Advisor'
      expect(account).to be_valid
    end
  end

  describe 'predicates' do
    it 'detects advisor accounts' do
      expect(IB::Account.new(account: 'F12345').advisor?).to be true
      expect(IB::Account.new(type: 'Advisor').advisor?).to be true
    end

    it 'detects user accounts' do
      expect(IB::Account.new(account: 'U12345').user?).to be true
      expect(IB::Account.new(type: 'User').user?).to be true
    end

    it 'detects test environment' do
      expect(IB::Account.new(account: 'DU12345').test_environment?).to be true
      expect(IB::Account.new(account: 'U12345').test_environment?).to be false
    end
  end

  describe '#print_type' do
    it 'returns user for user accounts' do
      expect(IB::Account.new(account: 'U12345', type: 'User').print_type).to eq('user')
    end

    it 'prefixes demo accounts' do
      expect(IB::Account.new(account: 'DU12345', type: 'User').print_type).to eq('demo_user')
    end

    it 'returns advisor for advisor accounts' do
      expect(IB::Account.new(account: 'F12345', type: 'Advisor').print_type).to eq('advisor')
    end
  end

  describe '#to_human' do
    it 'includes alias when present' do
      expect(account.to_human).to include('main')
      expect(account.to_human).to include('U12345')
    end

    it 'omits alias equal to account' do
      account.alias = 'U12345'
      expect(account.to_human).not_to include('alias')
    end

    it 'omits blank alias' do
      account.alias = ''
      expect(account.to_human).not_to include('alias')
    end
  end

  describe '#name' do
    it 'returns alias when present' do
      expect(account.name).to eq('main')
    end

    it 'falls back to account' do
      account.alias = ''
      expect(account.name).to eq('U12345')
    end
  end

  describe '#==' do
    it 'matches by account' do
      other = IB::Account.new(account: 'U12345')
      expect(account).to eq(other)
    end

    it 'differs by account' do
      other = IB::Account.new(account: 'U99999')
      expect(account).not_to eq(other)
    end
  end

  describe 'associations' do
    it 'has portfolio_values array' do
      expect(account.portfolio_values).to eq([])
    end

    it 'has orders array' do
      expect(account.orders).to eq([])
    end
  end
end
