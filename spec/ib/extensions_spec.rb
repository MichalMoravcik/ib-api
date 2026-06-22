require "spec_helper"

# Test if tweeking of basic classes works as expected

RSpec.describe ClassExtensions do

  context "Array-Extensions" do
    it "counts duplicates" do
      arr = [1, 2, 2, 3, 3, 3]
      expect(arr.count_duplicates).to eq({ 3 => 3, 2 => 2, 1 => 1 })
    end

    it "presents as table when elements respond to table_header and table_row" do
      contract = IB::Stock.new(symbol: 'AAPL', con_id: 1, exchange: 'SMART', currency: 'USD')
      table = [contract].as_table
      expect(table).to be_a(Terminal::Table)
      expect(table.render).to include('AAPL')
    end

    it "renders multiple rows in table" do
      contracts = [
        IB::Stock.new(symbol: 'AAPL', con_id: 1, exchange: 'SMART', currency: 'USD'),
        IB::Stock.new(symbol: 'MSFT', con_id: 2, exchange: 'SMART', currency: 'USD')
      ]
      table = contracts.as_table
      expect(table.render).to include('AAPL')
      expect(table.render).to include('MSFT')
    end
  end

  context "Date-Extensions" do
    it "renders date in IB format" do
      date = Date.new(2024, 12, 20)
      expect(date.to_ib).to start_with('20241220')
    end

    it "renders with timezone" do
      date = Date.new(2024, 12, 20)
      expect(date.to_ib('MET')).to include('MET')
    end
  end
  context "Time-Extensions" do
    Given( :the_time ){ Time.now }
    Then{ the_time.to_ib == the_time.strftime("%Y%m%d %H:%M:%S") }
  end

  # Numeric positive Values are true, zero and below is false
  context "numeric boolean Test" do
    Given( :the_var ){  45 }
    Then{ the_var.is_a? Numeric }
    Then{ the_var.to_bool }
    Given( :the_zero_var ){  0 }
    Then{ !the_zero_var.to_bool }
    Given( :the_negative_var ){  -54 }
    Then{ !the_zero_var.to_bool }
  end

  context "string boolean Tests" do 
    Given( :the_var ){ "false" }
    Then{ !the_var.to_bool }
    Given( :the_f_var ){ "f" }
    Then{ !the_var.to_bool }
    Given( :the_true_var ){ "true" }
    Then{ the_true_var.to_bool }
    Given( :the_t_var ){ "t" }
    Then{ the_true_var.to_bool }
    Given( :the_1_var ){ "1" }
    Then{ the_1_var.to_bool }
    Given( :the_0_var ){ "0" }
    Then{ !the_0_var.to_bool }
    Given( :the_empty_var ){ "" }
    Then{ !the_empty_var.to_bool }
    Given( :the_nonempty_var ){ "not empty" }
    Then{ expect{ the_nonempty_var.to_bool }.to raise_error( IB::Error )  }
  end

  context "native boolean Tests" do 
    Given( :the_var  ){ true }
    Then{ the_var.to_bool  }

    Given( :the_false_var ){ false }
    Then{ !the_false_var.to_bool }

    Given( :the_nil_var ){ nil }
    Then{ !the_nil_var.to_bool }
  end

end
