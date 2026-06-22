require 'main_helper'

# Edge-case tests for ReceiveFA message

RSpec.describe IB::Messages::Incoming::ReceiveFA do
  describe 'with single account alias (hash format)' do
    subject do
      described_class.new([
        3, # type - account aliases
        '<?xml version="1.0"?><ListOfAccountAliases><AccountAlias><accountDU>DU123456</accountDU><alias>MyMain</alias></AccountAlias></ListOfAccountAliases>'
      ])
    end

    it 'parses single account correctly' do
      accounts = subject.accounts
      expect(accounts).to be_an(Array)
      expect(accounts.size).to eq 1
      expect(accounts.first.account).to eq 'DU123456'
      expect(accounts.first.alias).to eq 'MyMain'
    end

    it 'has correct to_human' do
      human = subject.to_human
      expect(human).to include('FA')
      expect(human).to include('MyMain')
    end
  end

  describe 'with multiple account aliases (array format)' do
    subject do
      described_class.new([
        3, # type - account aliases
        '<?xml version="1.0"?><ListOfAccountAliases><AccountAlias><accountDU>DU111</accountDU><alias>First</alias></AccountAlias><AccountAlias><accountDU>DU222</accountDU><alias>Second</alias></AccountAlias></ListOfAccountAliases>'
      ])
    end

    it 'parses multiple accounts correctly' do
      accounts = subject.accounts
      expect(accounts.size).to eq 2
      expect(accounts[0].alias).to eq 'First'
      expect(accounts[1].alias).to eq 'Second'
    end
  end

  describe 'with fa_data_type 1 (GROUPS)' do
    subject do
      described_class.new([
        1, # type - GROUPS
        '<?xml version="1.0"?><FAData><Group><name>Group1</name></Group></FAData>'
      ])
    end

    it 'parses xml correctly' do
      expect(subject.xml).to be_a(Hash)
      expect(subject.type).to eq 1
    end
  end

  describe 'with fa_data_type 2 (PROFILE)' do
    subject do
      described_class.new([
        2, # type - PROFILE
        '<?xml version="1.0"?><FAData><Profile><name>Profile1</name></Profile></FAData>'
      ])
    end

    it 'parses xml correctly' do
      expect(subject.xml).to be_a(Hash)
      expect(subject.type).to eq 2
    end
  end

  describe 'message_id' do
    it 'has correct message_id' do
      expect(described_class.message_id).to eq 16
    end
  end
end
