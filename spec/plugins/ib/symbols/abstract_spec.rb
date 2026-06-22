# frozen_string_literal: true

# IB::Symbols requires plugin activation via IB::Connection
# These tests are integration tests that require a real connection
RSpec.describe IB::Contract, :integration do
  describe "#yml_file" do
    it "returns a Pathname to contract_config.yml" do
      contract = IB::Stock.new
      expect(contract.yml_file).to be_a(Pathname)
      expect(contract.yml_file.to_s).to include("contract_config.yml")
    end
  end
end
