# frozen_string_literal: true

RSpec.describe IB::PrepareData do
  using IB::Support

  subject { Object.new.tap { |o| o.extend(IB::PrepareData) } }

  describe "#prepare_message" do
    it "prepares a string message with EOL" do
      result = subject.prepare_message("test")
      expect(result).to be_a(String)
      expect(result.bytes[4..-1].pack("c*")).to eq("test\0")
    end

    it "prepares a symbol message" do
      result = subject.prepare_message(:hello)
      expect(result.bytes[4..-1].pack("c*")).to eq("hello\0")
    end

    it "prepares a numeric message" do
      result = subject.prepare_message(42)
      expect(result.bytes[4..-1].pack("c*")).to eq("42\0")
    end

    it "prepares a boolean true" do
      result = subject.prepare_message(true)
      expect(result.bytes[4..-1].pack("c*")).to eq("1\0")
    end

    it "prepares a boolean false" do
      result = subject.prepare_message(false)
      expect(result.bytes[4..-1].pack("c*")).to eq("0\0")
    end

    it "does not add EOL if message already ends with EOL" do
      result = subject.prepare_message("test\0")
      # Should not double the null terminator
      expect(result.bytes[4..-1].pack("c*")).to eq("test\0")
    end
  end

  describe "#decode_message" do
    it "decodes a simple packed message" do
      # Pack a message: size (4 bytes network order) + content
      content = "1\0value\0"
      packed = [content.bytesize].pack("N") + content
      result = subject.decode_message(packed)
      expect(result).to be_a(Hash)
      expect(result[1]).to eq(["value"])
    end

    it "decodes multiple messages" do
      # Pack two messages
      msg1 = "1\0first\0"
      msg2 = "2\0second\0"
      packed = [msg1.bytesize].pack("N") + msg1 + [msg2.bytesize].pack("N") + msg2
      result = subject.decode_message(packed)
      expect(result[1]).to eq(["first"])
      expect(result[2]).to eq(["second"])
    end

    it "yields to block if given" do
      content = "1\0value\0"
      packed = [content.bytesize].pack("N") + content
      yielded = nil
      subject.decode_message(packed) { |msg| yielded = msg[1..-1] }
      expect(yielded).to eq(["value"])
    end

    it "returns nil when message is empty" do
      expect(subject.decode_message("")).to be_nil
    end
  end
end
