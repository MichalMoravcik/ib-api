# frozen_string_literal: true

RSpec.describe IB::VERSION do
  it "is defined as a constant" do
    expect(defined?(IB::VERSION)).to eq("constant")
  end

  it "is a non-empty string" do
    expect(IB::VERSION).to be_a(String)
    expect(IB::VERSION).not_to be_empty
  end
end

RSpec.describe IB::Version do
  it "is defined and equals VERSION" do
    expect(defined?(IB::Version)).to eq("constant")
    expect(IB::Version).to eq(IB::VERSION)
  end
end

RSpec.describe IB::VERSION_FILE do
  it "is a Pathname" do
    expect(IB::VERSION_FILE).to be_a(Pathname)
  end

  it "points to a file that exists" do
    expect(IB::VERSION_FILE.exist?).to be true
  end

    it "has expected parent path structure" do
      expect(IB::VERSION_FILE.dirname.to_s).to include("ib-api")
    end
end
