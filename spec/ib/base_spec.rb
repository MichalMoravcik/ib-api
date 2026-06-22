require 'spec_helper'

describe IB::Base do
  let(:model_class) do
    Class.new(IB::Base) do
      include IB::BaseProperties
      prop :name, :value
    end
  end

  describe '#initialize' do
    it 'accepts a hash of attributes' do
      obj = model_class.new(name: 'test', value: 123)
      expect(obj.name).to eq('test')
      expect(obj.value).to eq(123)
    end

    it 'raises error if attributes is not a hash' do
      expect {
        model_class.new('not a hash')
      }.to raise_error(IB::ArgumentError, /Argument must be a Hash/)
    end
  end

  describe '#server_version' do
    it 'returns connection server version' do
      connection = IB::Connection.new
      allow(IB::Connection).to receive(:current).and_return(connection)
      allow(connection).to receive(:server_version).and_return(123)
      obj = model_class.new
      expect(obj.server_version).to eq(123)
    end

    it 'returns default version when no connection' do
      allow(IB::Connection).to receive(:current).and_return(nil)
      obj = model_class.new
      expect(obj.server_version).to eq(165)
    end
  end

  describe '#attributes' do
    it 'returns a hash' do
      obj = model_class.new(name: 'test')
      expect(obj.attributes).to be_a(Hash)
      expect(obj.attributes[:name]).to eq('test')
    end

    it 'is lazy initialized' do
      obj = model_class.new
      expect(obj.attributes).to be_a(Hash)
    end
  end

  describe '#attributes=' do
    it 'sets attributes via keys' do
      obj = model_class.new
      obj.attributes = { name: 'set', value: 456 }
      expect(obj.name).to eq('set')
      expect(obj.value).to eq(456)
    end
  end

  describe '#[] and #[]=' do
    it 'accesses attributes by key' do
      obj = model_class.new(name: 'test')
      expect(obj[:name]).to eq('test')
      obj[:name] = 'changed'
      expect(obj[:name]).to eq('changed')
    end

    it 'converts symbol keys' do
      obj = model_class.new(name: 'test')
      expect(obj['name']).to eq('test')
    end
  end

  describe '#update_attribute' do
    it 'updates a single attribute' do
      obj = model_class.new(name: 'original')
      obj.update_attribute(:name, 'updated')
      expect(obj.name).to eq('updated')
    end
  end

  describe '#to_model' do
    it 'returns self' do
      obj = model_class.new
      expect(obj.to_model).to eq(obj)
    end
  end

  describe '#new_record?' do
    it 'always returns true' do
      obj = model_class.new
      expect(obj.new_record?).to eq(true)
    end
  end

  describe '#save' do
    it 'returns result of valid?' do
      obj = model_class.new
      expect(obj.save).to eq(obj.valid?)
    end
  end

  describe '.attr_protected' do
    it 'is a noop' do
      expect {
        model_class.attr_protected :name
      }.not_to raise_error
    end
  end

  describe '.attr_accessible' do
    it 'is a noop' do
      expect {
        model_class.attr_accessible :name
      }.not_to raise_error
    end
  end

  describe '.belongs_to' do
    it 'creates an accessor' do
      klass = Class.new(IB::Base) do
        belongs_to :user
      end
      obj = klass.new
      obj.user = 'test_user'
      expect(obj.user).to eq('test_user')
    end
  end

  describe '.has_one' do
    it 'creates an accessor' do
      klass = Class.new(IB::Base) do
        has_one :profile
      end
      obj = klass.new
      obj.profile = 'test_profile'
      expect(obj.profile).to eq('test_profile')
    end
  end

  describe '.has_many' do
    it 'creates an accessor that returns an array' do
      klass = Class.new(IB::Base) do
        has_many :items
      end
      obj = klass.new
      expect(obj.items).to be_an(Array)
      obj.items << 'item1'
      expect(obj.items).to include('item1')
    end
  end

  describe '.find' do
    it 'returns empty array' do
      expect(model_class.find(:all)).to eq([])
    end

    it 'returns empty array for any args' do
      expect(model_class.find(1)).to eq([])
    end
  end

  describe '.serialize' do
    it 'is a noop' do
      expect {
        model_class.serialize :name
      }.not_to raise_error
    end
  end
end
