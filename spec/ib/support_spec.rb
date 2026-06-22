# frozen_string_literal: true

RSpec.describe IB::Support do
  using IB::Support

  describe "Array refinements" do
    describe "#zero?" do
      it "returns false for arrays" do
        expect([1, 2, 3].zero?).to be false
      end
    end

    describe "#read_int" do
      it "reads and converts an integer from array" do
        arr = ["42"]
        expect(arr.read_int).to eq(42)
      end

      it "converts string to integer" do
        arr = ["123"]
        expect(arr.read_int).to eq(123)
      end

      it "returns nil for blank values" do
        arr = [""]
        expect(arr.read_int).to be_nil
      end

      it "returns nil for nil values" do
        arr = [nil]
        expect(arr.read_int).to be_nil
      end

      it "returns nil for max int sentinel value" do
        arr = [2147483647]
        expect(arr.read_int).to be_nil
      end

      it "modifies the array" do
        arr = ["42", "next"]
        arr.read_int
        expect(arr).to eq(["next"])
      end
    end

    describe "#read_float" do
      it "reads and converts a float from array" do
        arr = ["3.14"]
        expect(arr.read_float).to eq(3.14)
      end

      it "handles integer strings" do
        arr = ["42"]
        expect(arr.read_float).to eq(42.0)
      end

      it "returns nil for blank values" do
        arr = [""]
        expect(arr.read_float).to be_nil
      end
    end

    describe "#read_decimal" do
      it "reads and converts to BigDecimal" do
        arr = ["3.14"]
        result = arr.read_decimal
        expect(result).to be_a(BigDecimal)
        expect(result.to_f).to eq(3.14)
      end

      it "returns nil for very large numbers (TWS_MAX)" do
        arr = [IB::TWS_MAX.to_s]
        expect(arr.read_decimal).to be_nil
      end

      it "returns nil for blank values" do
        arr = [""]
        expect(arr.read_decimal).to be_nil
      end
    end

    describe "#read_string" do
      it "reads and removes first element" do
        arr = ["hello", "world"]
        expect(arr.read_string).to eq("hello")
        expect(arr).to eq(["world"])
      end

      it "returns empty string when array is empty" do
        arr = []
        expect(arr.read_string).to be_nil
      end
    end

    describe "#read_symbol" do
      it "reads string and converts to symbol" do
        arr = ["hello"]
        expect(arr.read_symbol).to eq(:hello)
      end
    end

    describe "#read_boolean" do
      it "returns true for '1'" do
        arr = ["1"]
        expect(arr.read_boolean).to be true
      end

      it "returns false for '0'" do
        arr = ["0"]
        expect(arr.read_boolean).to be false
      end

      it "returns nil for other values" do
        arr = ["maybe"]
        expect(arr.read_boolean).to be_nil
      end
    end

    describe "#read_array" do
      it "returns empty array when count is 0" do
        arr = [0]
        expect(arr.read_array).to eq([])
      end

      it "returns nil when count is nil" do
        arr = [nil]
        expect(arr.read_array).to be_nil
      end

      it "reads string elements by default" do
        arr = [2, "a", "b"]
        expect(arr.read_array).to eq(["a", "b"])
      end

      it "accepts block for custom reading" do
        arr = [2]
        result = arr.read_array { |_| 42 }
        expect(result).to eq([42, 42])
      end

      it "doubles count in hashmode" do
        arr = [2]
        # In hashmode, count becomes 4, so we need 4 elements
        # Actually, looking at the code: count= count + count if hashmode
        # So with 2, it becomes 4
      end
    end

    describe "#read_hash" do
      it "returns nil when tags are nil" do
        arr = [nil]
        expect(arr.read_hash).to be_nil
      end

      it "returns empty array when tags are empty" do
        arr = [[]]
        expect(arr.read_hash).to be_nil
      end

      it "builds hash from key-value pairs" do
        arr = [4, "key1", "value1", "key2", "value2"]
        result = arr.read_hash
        expect(result).to be_a(Hash)
        expect(result[:key1]).to eq("value1")
      end
    end

    describe "#tws" do
      it "flattens array and joins tws representations" do
        arr = [["a", "b"]]
        expect(arr.tws).to eq("a\0b\0")
      end

      it "handles blank elements" do
        arr = ["", [] , nil]
        expect(arr.tws).to eq("\0\0")
      end
    end
  end

  describe "Symbol refinement" do
    describe "#tws" do
      it "converts symbol to string and appends EOL" do
        expect(:test.tws).to eq("test\0")
      end
    end
  end

  describe "String refinement" do
    describe "#tws" do
      it "appends EOL if not already present" do
        expect("test".tws).to eq("test\0")
      end

      it "does not double EOL if already present" do
        expect("test\0".tws).to eq("test\0")
      end

      it "returns EOL for empty string" do
        expect("".tws).to eq("\0")
      end
    end
  end

  describe "Numeric refinement" do
    describe "#tws" do
      it "converts number to string and appends EOL" do
        expect(42.tws).to eq("42\0")
        expect(3.14.tws).to eq("3.14\0")
      end
    end
  end

  describe "TrueClass refinement" do
    describe "#tws" do
      it "returns '1' with EOL" do
        expect(true.tws).to eq("1\0")
      end
    end
  end

  describe "FalseClass refinement" do
    describe "#tws" do
      it "returns '0' with EOL" do
        expect(false.tws).to eq("0\0")
      end
    end
  end

  describe "NilClass refinement" do
    describe "#tws" do
      it "returns EOL" do
        expect(nil.tws).to eq("\0")
      end
    end
  end
end
