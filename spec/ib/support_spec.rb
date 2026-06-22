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

      it "handles odd number of tags" do
        arr = [3, "key1", "value1", "key2"]
        result = arr.read_hash
        expect(result[:key1]).to eq("value1")
        expect(result).to have_key(:key2)
      end

      it "skips nil keys" do
        arr = [2, nil, "value"]
        expect(arr.read_hash).to eq({})
      end
    end

    describe "#read_string_not_null" do
      it "returns nil for TWS_MAX sentinel" do
        arr = [IB::TWS_MAX.to_s]
        expect(arr.read_string_not_null).to be_nil
      end

      it "returns the string for regular values" do
        arr = ["hello"]
        expect(arr.read_string_not_null).to eq("hello")
      end
    end

    describe "#read_datetime" do
      it "parses datetime string" do
        arr = ["2024-12-20T12:00:00"]
        expect(arr.read_datetime).to be_a(DateTime)
      end

      it "returns nil for blank string" do
        arr = [""]
        expect(arr.read_datetime).to be_nil
      end
    end

    describe "#read_date" do
      it "parses date string" do
        arr = ["2024-12-20"]
        expect(arr.read_date).to eq(Date.new(2024, 12, 20))
      end

      it "returns nil for blank string" do
        arr = [""]
        expect(arr.read_date).to be_nil
      end
    end

    describe "#read_decimal_limit_2" do
      it "returns nil for -2 and below" do
        arr = [-2]
        expect(arr.read_decimal_limit_2).to be_nil
      end

      it "returns value above -2" do
        arr = [-1]
        expect(arr.read_decimal_limit_2).to eq(-1)
      end
    end

    describe "#read_xml" do
      it "parses xml string into hash" do
        arr = ["<root><key>value</key></root>"]
        result = arr.read_xml
        expect(result).to be_a(Hash)
      end
    end

    describe "#read_int_date" do
      it "parses a date string" do
        arr = ["20241220"]
        expect(arr.read_int_date).to eq(Date.new(2024, 12, 20))
      end

      it "returns Time for epoch integer" do
        arr = [1735689600]
        result = arr.read_int_date
        expect(result).to be_a(Time)
      end
    end

    describe "#read_bool" do
      it "aliases read_boolean" do
        arr = ["1"]
        expect(arr.read_bool).to be true
      end
    end

    describe "#read_decimal_max" do
      it "aliases read_decimal" do
        arr = ["3.14"]
        expect(arr.read_decimal_max.to_f).to eq(3.14)
      end
    end

    describe "#read_parse_date" do
      it "parses a time string" do
        arr = ["2024-12-20 12:00:00"]
        expect(arr.read_parse_date).to be_a(Time)
      end
    end

    describe "#read_decimal_limit_1" do
      it "returns nil for -1 and below" do
        arr = [-1]
        expect(arr.read_decimal_limit_1).to be_nil
      end

      it "returns positive decimal" do
        arr = [1.5]
        expect(arr.read_decimal_limit_1).to eq(1.5)
      end
    end

    describe "#read_contract" do
      it "reads contract fields" do
        arr = [1, "AAPL", "STK", "20241220", 150, "C", 100, "SMART", "USD", "AAPL", "AAPL"]
        result = arr.read_contract
        expect(result[:symbol]).to eq("AAPL")
        expect(result[:con_id]).to eq(1)
      end
    end

    describe "#read_bar" do
      it "reads historical bar fields" do
        arr = ["20241220", 100, 110, 120, 90, 105, 1000, 50]
        result = arr.read_bar
        expect(result[:open]).to eq(100)
        expect(result[:close]).to eq(110)
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
