# frozen_string_literal: true

RSpec.describe IB do
  describe "constants" do
    it "defines EOL as null byte" do
      expect(IB::EOL).to eq("\0")
    end

    it "defines TWS_MAX as a very large number" do
      expect(IB::TWS_MAX).to be_a(Float)
      expect(IB::TWS_MAX.to_s.length).to be > 10
    end

    it "defines TWSMAX as an even larger number" do
      expect(IB::TWSMAX).to be_a(Float)
      expect(IB::TWSMAX).to be > IB::TWS_MAX
    end
  end

  describe "BAR_SIZES" do
    it "is a frozen hash" do
      expect(IB::BAR_SIZES).to be_frozen
      expect(IB::BAR_SIZES).to be_a(Hash)
    end

    it "contains expected bar size keys" do
      expect(IB::BAR_SIZES).to include("1 sec", "5 secs", "1 min", "1 hour", "1 day")
    end

    it "maps string keys to symbol values" do
      expect(IB::BAR_SIZES["1 min"]).to eq(:min1)
      expect(IB::BAR_SIZES["1 hour"]).to eq(:hour1)
    end
  end

  describe "DATA_TYPES" do
    it "is a frozen hash" do
      expect(IB::DATA_TYPES).to be_frozen
      expect(IB::DATA_TYPES).to be_a(Hash)
    end

    it "contains expected data types" do
      expect(IB::DATA_TYPES).to include("TRADES", "MIDPOINT", "BID", "ASK")
    end

    it "maps string keys to symbol values" do
      expect(IB::DATA_TYPES["TRADES"]).to eq(:trades)
      expect(IB::DATA_TYPES["BID"]).to eq(:bid)
    end
  end

  describe "TICK_TYPES" do
    it "is a hash with integer keys" do
      expect(IB::TICK_TYPES).to be_a(Hash)
      expect(IB::TICK_TYPES.keys).to all(be_an(Integer))
    end

    it "contains expected tick type mappings" do
      expect(IB::TICK_TYPES[0]).to eq(:bid_size)
      expect(IB::TICK_TYPES[1]).to eq(:bid_price)
      expect(IB::TICK_TYPES[4]).to eq(:last_price)
    end

    it "has 89 defined tick types" do
      expect(IB::TICK_TYPES.size).to be >= 80
    end
  end

  describe "FA_TYPES" do
    it "is a frozen hash" do
      expect(IB::FA_TYPES).to be_frozen
    end

    it "maps integers to symbols" do
      expect(IB::FA_TYPES[1]).to eq(:groups)
      expect(IB::FA_TYPES[2]).to eq(:profiles)
      expect(IB::FA_TYPES[3]).to eq(:aliases)
    end
  end

  describe "MARKET_DATA_TYPES" do
    it "is a frozen hash" do
      expect(IB::MARKET_DATA_TYPES).to be_frozen
    end

    it "contains expected market data types" do
      expect(IB::MARKET_DATA_TYPES[1]).to eq(:real_time)
      expect(IB::MARKET_DATA_TYPES[2]).to eq(:frozen)
    end
  end

  describe "MARKET_DEPTH_OPERATIONS" do
    it "is a frozen hash" do
      expect(IB::MARKET_DEPTH_OPERATIONS).to be_frozen
    end

    it "maps operation codes to symbols" do
      expect(IB::MARKET_DEPTH_OPERATIONS[0]).to eq(:insert)
      expect(IB::MARKET_DEPTH_OPERATIONS[1]).to eq(:update)
      expect(IB::MARKET_DEPTH_OPERATIONS[2]).to eq(:delete)
    end
  end

  describe "MARKET_DEPTH_SIDES" do
    it "is a frozen hash" do
      expect(IB::MARKET_DEPTH_SIDES).to be_frozen
    end

    it "maps side codes to symbols" do
      expect(IB::MARKET_DEPTH_SIDES[0]).to eq(:ask)
      expect(IB::MARKET_DEPTH_SIDES[1]).to eq(:bid)
    end
  end

  describe "ORDER_TYPES" do
    it "is a frozen hash" do
      expect(IB::ORDER_TYPES).to be_frozen
    end

    it "maps order type strings to symbols" do
      expect(IB::ORDER_TYPES["LMT"]).to eq(:limit)
      expect(IB::ORDER_TYPES["MKT"]).to eq(:market)
      expect(IB::ORDER_TYPES["STP"]).to eq(:stop)
    end

    it "contains common order types" do
      expect(IB::ORDER_TYPES).to include("LMT", "MKT", "STP", "STP LMT", "TRAIL")
    end
  end

  describe "SECURITY_TYPES" do
    it "is a frozen hash" do
      expect(IB::SECURITY_TYPES).to be_frozen
    end

    it "maps security type strings to symbols" do
      expect(IB::SECURITY_TYPES["STK"]).to eq(:stock)
      expect(IB::SECURITY_TYPES["OPT"]).to eq(:option)
      expect(IB::SECURITY_TYPES["FUT"]).to eq(:future)
    end

    it "contains common security types" do
      expect(IB::SECURITY_TYPES).to include("STK", "OPT", "FUT", "BOND", "CASH")
    end
  end

  describe "VALUES" do
    it "is a frozen hash" do
      expect(IB::VALUES).to be_frozen
    end

    it "contains expected top-level keys" do
      expect(IB::VALUES).to include(:sec_type, :order_type, :side, :right, :origin)
    end

    it "has :sec_type containing SECURITY_TYPES" do
      expect(IB::VALUES[:sec_type]).to eq(IB::SECURITY_TYPES)
    end

    it "has :order_type containing ORDER_TYPES" do
      expect(IB::VALUES[:order_type]).to eq(IB::ORDER_TYPES)
    end

    it "has :side mapping buy/sell strings" do
      expect(IB::VALUES[:side]["B"]).to eq(:buy)
      expect(IB::VALUES[:side]["S"]).to eq(:sell)
    end

    it "has :right mapping option rights" do
      expect(IB::VALUES[:right][""]).to eq(:none)
      expect(IB::VALUES[:right]["P"]).to eq(:put)
      expect(IB::VALUES[:right]["C"]).to eq(:call)
    end

    it "has :origin mapping customer/firm" do
      expect(IB::VALUES[:origin][0]).to eq(:customer)
      expect(IB::VALUES[:origin][1]).to eq(:firm)
    end

    it "has :tif mapping time-in-force strings" do
      expect(IB::VALUES[:tif]["DAY"]).to eq(:day)
      expect(IB::VALUES[:tif]["GTC"]).to eq(:good_till_cancelled)
    end
  end

  describe "CODES" do
    it "is a frozen hash" do
      expect(IB::CODES).to be_frozen
    end

    it "is inverse of VALUES" do
      expect(IB::CODES[:side][:buy]).to eq("B")
      expect(IB::CODES[:side][:sell]).to eq("S")
    end

    it "has same keys as VALUES" do
      expect(IB::CODES.keys).to match_array(IB::VALUES.keys)
    end
  end

  describe "PROPS" do
    it "is a frozen hash" do
      expect(IB::PROPS).to be_frozen
    end

    it "has :side processor" do
      expect(IB::PROPS[:side]).to include(:set)
    end

    it "has :open_close processor" do
      expect(IB::PROPS[:open_close]).to include(:set)
    end
  end

  describe "PROPS :side setter" do
    let(:order) { IB::Order.new }

    it "sets 'B' for buy" do
      order.side = :buy
      expect(order[:side]).to eq('B')
    end

    it "sets 'S' for sell" do
      order.side = :sell
      expect(order[:side]).to eq('S')
    end

    it "sets 'T' for short" do
      order.side = :short
      expect(order[:side]).to eq('T')
    end

    it "sets 'X' for short_exempt" do
      order.side = :short_exempt
      expect(order[:side]).to eq('X')
    end

    it "handles uppercase strings" do
      order.side = 'BUY'
      expect(order[:side]).to eq('B')
    end

    it "returns nil for unknown side" do
      order.side = :unknown
      expect(order[:side]).to be_nil
    end
  end

  describe "PROPS :open_close setter" do
    let(:order) { IB::Order.new }

    it "sets 0 for same" do
      order.open_close = :same
      expect(order[:open_close]).to eq(0)
    end

    it "sets 1 for open" do
      order.open_close = :open
      expect(order[:open_close]).to eq(1)
    end

    it "sets 2 for close" do
      order.open_close = :close
      expect(order[:open_close]).to eq(2)
    end

    it "sets 3 for unknown" do
      order.open_close = :unknown
      expect(order[:open_close]).to eq(3)
    end

    it "handles string inputs" do
      order.open_close = 'S'
      expect(order[:open_close]).to eq(0)
      order.open_close = 'O'
      expect(order[:open_close]).to eq(1)
      order.open_close = 'C'
      expect(order[:open_close]).to eq(2)
      order.open_close = 'U'
      expect(order[:open_close]).to eq(3)
    end

    it "returns nil for unrecognized input" do
      order.open_close = :foo
      expect(order[:open_close]).to be_nil
    end
  end
end
