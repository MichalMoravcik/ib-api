# frozen_string_literal: true

RSpec.describe Support::ArrayFunction do
  before(:all) { Array.include Support::ArrayFunction }

  let(:array) { [] }

  describe '#save_insert' do
    context 'when member with matching key exists and overwrite is true' do
      let(:array) { [{ id: 1, name: 'original' }] }
      let(:item) { { id: 1, name: 'updated' } }

      it 'overwrites the existing member' do
        result = array.save_insert(item, :id, true)
        expect(result).to eq([{ id: 1, name: 'updated' }])
      end
    end

    context 'when member with matching key exists and overwrite is false' do
      let(:array) { [{ id: 1, name: 'original' }] }
      let(:item) { { id: 1, name: 'updated' } }

      it 'does not overwrite the existing member' do
        result = array.save_insert(item, :id, false)
        expect(result).to eq([{ id: 1, name: 'original' }])
      end
    end

    context 'when no member with matching key exists' do
      let(:array) { [{ id: 1, name: 'existing' }] }
      let(:item) { { id: 2, name: 'new' } }

      it 'appends the new item' do
        result = array.save_insert(item, :id)
        expect(result).to eq([{ id: 1, name: 'existing' }, { id: 2, name: 'new' }])
      end
    end

    context 'with empty array' do
      let(:item) { { id: 1, name: 'first' } }

      it 'appends the item' do
        result = array.save_insert(item, :id)
        expect(result).to eq([{ id: 1, name: 'first' }])
      end
    end

    it 'always returns self' do
      result = array.save_insert({ id: 1 }, :id)
      expect(result).to be(array)
    end
  end

  describe '#intercept' do
    context 'with two intersecting arrays' do
      let(:array) { [[1, 2, 3], [2, 3, 4]] }

      it 'returns the first common element' do
        expect(array.intercept).to eq(2)
      end
    end

    context 'with no intersection' do
      let(:array) { [[1, 2, 3], [4, 5, 6]] }

      it 'returns nil' do
        expect(array.intercept).to be_nil
      end
    end

    context 'with single array' do
      let(:array) { [[1, 2, 3]] }

      it 'returns first element' do
        expect(array.intercept).to eq(1)
      end
    end

    context 'with empty array' do
      let(:array) { [] }

      it 'returns nil' do
        expect(array.intercept).to be_nil
      end
    end

    context 'with arrays having nil intersection result' do
      let(:array) { [[nil], [nil]] }

      it 'returns nil (not nilClass)' do
        expect(array.intercept).to be_nil
      end
    end
  end
end
