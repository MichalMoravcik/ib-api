# frozen_string_literal: true

RSpec.describe IB::Error do
  it "is a RuntimeError" do
    expect(described_class.new("test")).to be_a(RuntimeError)
  end

  it "contains the message" do
    error = described_class.new("something went wrong")
    expect(error.message).to eq("something went wrong")
  end
end

RSpec.describe IB::ArgumentError do
  it "is an ArgumentError" do
    expect(described_class.new("invalid argument")).to be_a(ArgumentError)
  end
end

RSpec.describe IB::SymbolError do
  it "is an IB::ArgumentError" do
    expect(described_class.new("unknown symbol")).to be_a(IB::ArgumentError)
  end
end

RSpec.describe IB::LoadError do
  it "is a LoadError" do
    expect(described_class.new("failed to load")).to be_a(LoadError)
  end
end

RSpec.describe IB::FlexError do
  it "is a RuntimeError" do
    expect(described_class.new("flex error")).to be_a(RuntimeError)
  end
end

RSpec.describe IB::TransmissionError do
  it "is a RuntimeError" do
    expect(described_class.new("transmission failed")).to be_a(RuntimeError)
  end
end

RSpec.describe IB::VerifyError do
  it "is a StandardError" do
    expect(described_class.new("verification failed")).to be_a(StandardError)
  end
end

RSpec.describe "top-level error method" do
  it "raises IB::Error for :standard type" do
    expect { error("test", :standard) }.to raise_error(IB::Error)
  end

  it "raises IB::ArgumentError for :args type" do
    expect { error("test", :args) }.to raise_error(IB::ArgumentError)
  end

  it "raises IB::SymbolError for :symbol type" do
    expect { error("test", :symbol) }.to raise_error(IB::SymbolError)
  end

  it "raises IB::LoadError for :load type" do
    expect { error("test", :load) }.to raise_error(IB::LoadError)
  end

  it "raises IB::FlexError for :flex type" do
    expect { error("test", :flex) }.to raise_error(IB::FlexError)
  end

  it "raises IB::TransmissionError for :reader type" do
    expect { error("test", :reader) }.to raise_error(IB::TransmissionError)
  end

  it "raises IB::VerifyError for :verify type" do
    expect { error("test", :verify) }.to raise_error(IB::VerifyError)
  end

  it "raises IB::Error when type is not recognized (returns nil case)" do
    expect { error("test", :unknown) }.to raise_error(TypeError)
  end
end
