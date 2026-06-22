require 'spec_helper'

class TestBaseModel < IB::Base
  include IB::BaseProperties
  prop :name,
       :count,
       [:label, :tag],
       :side => IB::PROPS[:side],
       :value => :f,
       :flag => :bool,
       :rating => { validate: { numericality: true } },
       :virtual => '',
       :computed => '',
       :encoded => { get: :s, set: :i }
end

describe IB::BaseProperties do
  let(:model_class) { TestBaseModel }

  describe '#to_human' do
    it 'returns a sorted attribute string' do
      obj = model_class.new(name: 'x', count: 3)
      expect(obj.to_human).to match(/<TestBaseModel: .*count: 3.*name: x.*>/)
    end

    it 'skips nil attributes' do
      obj = model_class.new(name: 'only')
      expect(obj.to_human).not_to include('count:')
    end
  end

  describe '#table_header and #table_row' do
    it 'return parallel arrays' do
      obj = model_class.new(name: 'x', count: 1)
      expect(obj.table_header.first).to eq(obj.class.to_s.demodulize)
      expect(obj.table_row.first).to eq(obj.class.to_s.demodulize)
      expect(obj.table_row[1..-1]).to eq(obj.table_header[1..-1].map { |k| obj.send(k) })
    end
  end

  describe '#content_attributes' do
    it 'filters metadata keys' do
      obj = model_class.new(name: 'x', count: 1)
      obj.instance_variable_set(:@id, 99)
      obj.instance_variable_set(:@order_id, 5)
      expect(obj.content_attributes).not_to include(:id, :order_id, :created_at)
      expect(obj.content_attributes).to include(:name, :count)
    end
  end

  describe '#invariant_attributes' do
    it 'removes timestamp keys' do
      obj = model_class.new(name: 'x', created_at: Time.now)
      expect(obj.invariant_attributes).not_to include(:created_at)
      expect(obj.invariant_attributes).to include(:name)
    end
  end

  describe '#update_missing' do
    it 'fills blank attributes from hash' do
      obj = model_class.new(name: 'x')
      obj.update_missing(count: 7, name: 'y')
      expect(obj.name).to eq('x')
      expect(obj.count).to eq(7)
    end

    it 'accepts another model' do
      source = model_class.new(name: 'src', count: 2)
      target = model_class.new(name: 'tgt')
      target.update_missing(source)
      expect(target.count).to eq(2)
      expect(target.name).to eq('tgt')
    end
  end

  describe '#==' do
    it 'matches equal content attributes' do
      a = model_class.new(name: 'x', count: 1)
      b = model_class.new(name: 'x', count: 1)
      expect(a).to eq(b)
    end

    it 'delegates string comparison to super' do
      obj = model_class.new(name: 'x')
      expect(obj).not_to eq('x')
    end
  end

  describe 'property definitions' do
    it 'creates simple accessor' do
      obj = model_class.new(name: 'foo')
      expect(obj.name).to eq('foo')
      obj.name = 'bar'
      expect(obj.name).to eq('bar')
    end

    it 'aliases properties' do
      obj = model_class.new(label: 'lbl')
      expect(obj.tag).to eq('lbl')
      obj.tag = 'tagged'
      expect(obj.label).to eq('tagged')
    end

    it 'encodes symbol/string properties' do
      obj = model_class.new(side: 'BUY')
      expect(obj.side).to eq(:buy)
      obj.side = :sell
      expect(obj[:side]).to eq('S')
    end

    it 'converts with to_f/to_i when configured' do
      obj = model_class.new(value: '3.14')
      expect(obj.value).to be_a(Float)
      expect(obj.value).to eq(3.14)
    end

    it 'decodes encoded properties from CODES' do
      obj = model_class.new(side: 'B')
      expect(obj.side).to eq(:buy)
      obj.side = :sell
      expect(obj[:side]).to eq('S')
    end

    it 'validates via hash option' do
      obj = model_class.new(rating: 'abc', side: :buy)
      expect(obj).not_to be_valid
      obj.rating = 5
      expect(obj).to be_valid
    end

    it 'handles empty string property body' do
      obj = model_class.new(virtual: 'test')
      expect(obj.virtual).to eq('test')
      obj.virtual = 'changed'
      expect(obj.virtual).to eq('changed')
    end

    it 'handles computed property' do
      obj = model_class.new(computed: 'value')
      expect(obj.computed).to eq('value')
      obj.computed = 'changed'
      expect(obj.computed).to eq('changed')
    end

    it 'handles encoded property with get/set procs' do
      obj = model_class.new
      obj.encoded = 100
      expect(obj.encoded).to eq('100')
      expect(obj.encoded).to be_a(String)
    end

    it 'handles property with IB::VALUES encoding' do
      obj = model_class.new(side: :buy)
      expect(obj.side).to eq(:buy)
    end

    it 'handles property with CODES encoding' do
      obj = model_class.new(side: :sell)
      expect(obj[:side]).to eq('S')
    end
  end

  describe 'default attributes' do
    it 'sets created_at on initialize' do
      obj = model_class.new
      expect(obj.created_at).to be_a(Time)
    end
  end
end
