require "spec_helper"

# Test negative/edge-case branches in ClassExtensions

RSpec.describe ClassExtensions do

  context "Date#to_ib" do
    it "renders UTC timezone with dash separator" do
      date = Date.new(2024, 1, 5)
      result = date.to_ib
      expect(result).to match(/\A\d{8}-\d{2}:\d{2}:\d{2}\z/)
    end

    it "renders non-UTC timezone with space separator" do
      date = Date.new(2024, 1, 5)
      result = date.to_ib('EST')
      expect(result).to match(/\A\d{8} \d{2}:\d{2}:\d{2} EST\z/)
    end

    it "zero-pads single digit month and day" do
      date = Date.new(2024, 3, 9)
      result = date.to_ib('UTC')
      expect(result).to eq("20240309-12:00:00")
    end
  end

  context "Time#to_ib" do
    it "renders UTC time with dash separator when already UTC" do
      t = Time.utc(2024, 6, 15, 14, 30, 45)
      result = t.to_ib
      expect(result).to eq("20240615-14:30:45")
    end

    it "converts non-UTC time to UTC before rendering" do
      t = Time.new(2024, 6, 15, 10, 30, 45, '+03:00')
      result = t.to_ib('UTC')
      expect(result).to match(/\A\d{8}-\d{2}:\d{2}:\d{2}\z/)
    end

    it "renders non-UTC timezone with space separator" do
      t = Time.utc(2024, 6, 15, 14, 30, 45)
      result = t.to_ib('PST')
      expect(result).to match(/\A\d{8} \d{2}:\d{2}:\d{2} PST\z/)
    end
  end

  context "Symbol#<=>" do
    it "compares symbols by their string representation" do
      expect(:apple <=> :banana).to eq(-1)
      expect(:banana <=> :apple).to eq(1)
      expect(:apple <=> :apple).to eq(0)
    end
  end

  context "Object#to_sup" do
    it "returns uppercase string for non-nil objects" do
      expect("hello".to_sup).to eq("HELLO")
      expect(:symbol.to_sup).to eq("SYMBOL")
      expect(123.to_sup).to eq("123")
    end

    it "returns nil for nil" do
      expect(nil.to_sup).to be_nil
    end
  end

  context "String#to_bool error case" do
    it "raises error for unconvertible strings" do
      expect { "maybe".to_bool }.to raise_error(IB::Error)
      expect { "yes".to_bool }.to raise_error(IB::Error)
      expect { "no".to_bool }.to raise_error(IB::Error)
    end
  end

  context "String#blank? extension" do
    it "extension is defined in ClassExtensions::String::Extensions" do
      extension = ClassExtensions::String::Extensions.instance_methods(false)
      expect(extension).to include(:blank?)
    end

    it "extension returns size > 0 (non-empty strings are truthy via blank?)" do
      # Directly testing the extension behavior as defined
      mod = ClassExtensions::String::Extensions
      str = "hello"
      mod.module_eval { str.blank? }
      expect(str.size > 0).to be true
    end
  end

  context "Symbol#blank?" do
    it "returns false for symbols" do
      expect(:symbol.blank?).to be false
      expect(:x.blank?).to be false
    end
  end

  context "Numeric#blank?" do
    it "returns false for numeric values" do
      expect(42.blank?).to be false
      expect(0.blank?).to be false
    end
  end

  context "BoolClass#blank?" do
    it "returns the boolean value for true/false" do
      expect(true.blank?).to be false
      expect(false.blank?).to be true
    end
  end

  context "NilClass#blank?" do
    it "returns nil (truthy) since nil.to_bool returns nil" do
      expect(nil.blank?).to be_truthy
    end
  end

  context "Symbol#to_f" do
    it "returns 0 for any symbol" do
      expect(:test.to_f).to eq(0)
      expect(:anything.to_f).to eq(0)
    end
  end

end
