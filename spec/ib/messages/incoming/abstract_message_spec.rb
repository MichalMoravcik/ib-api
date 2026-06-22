require 'main_helper'

RSpec.shared_examples_for "simple_instruction" do
  it { is_expected.to be_a IB::Messages::Incoming::AbstractMessage }
  its( :message_id ) { is_expected.to eq 1000 }
  its( :version )    { is_expected.to eq 1 }
  its( :data )       { is_expected.not_to  be_empty }
  its( :buffer  )    { is_expected.to be_empty }
end


RSpec.describe IB::Messages::Incoming::AbstractMessage do

  describe '#check_version' do
    let(:message_class) do
      Class.new(IB::Messages::Incoming::AbstractMessage) do
        @message_id = 9999
        @version = 5
      end
    end

    context 'when actual version matches expected version' do
      subject { message_class.new({}) }

      it 'does not raise error' do
        expect { subject.check_version(5, 5) }.not_to raise_error
      end
    end

    context 'when actual version is in expected array' do
      subject { message_class.new({}) }

      it 'does not raise error' do
        expect { subject.check_version(3, [1, 2, 3, 4]) }.not_to raise_error
      end
    end

    context 'when actual version does not match' do
      subject { message_class.new({}) }

      it 'logs error via error handler' do
        expect { subject.check_version(10, 5) }.to raise_error(IB::Error, /Unsupported version/)
      end
    end
  end

  describe '#valid?' do
    context 'with empty buffer' do
      subject { IB::Messages::Incoming::Alert.new(version: 2, error_id: 1, code: 500, message: 'test') }

      it 'returns true' do
        expect(subject.valid?).to be true
      end
    end
  end
end


RSpec.describe IB::Messages::Incoming   do

    let( :simple_instruction ){   IB::Messages::Incoming.def_message  1000  }
    let( :int_instruction ){   IB::Messages::Incoming.def_message 1000, [:the_integer, :int] }
    let( :string_instruction ){   IB::Messages::Incoming.def_message 1000, [:the_string, :string] }
    let( :decimal_instruction ){   IB::Messages::Incoming.def_message 1000, [:the_decimal, :decimal] }
    let( :boolean_instruction ){   IB::Messages::Incoming.def_message 1000, [:the_bool, :boolean] }
    let( :array_instruction ){   IB::Messages::Incoming.def_message 1000, [:the_array, :array ] }
    let( :hash_instruction ){   IB::Messages::Incoming.def_message 1000, [:the_hash, :hash] }


      #subject{ IB::Messages::Incoming.def_message 10 }

    context "simple Instruction" do
      subject{ simple_instruction.new ["1"] }
      it_behaves_like 'simple_instruction'
    end
    context "Instruction with Integer" do
      ## only the correct behavior implements the function. Other cases yield zero (0)
      context "correct Behavior" do
        subject{ int_instruction.new ["1","45"] }
        it_behaves_like 'simple_instruction'
        its(:the_integer){ is_expected.to be_a(Integer).and eq(45) }
      end
      context "false Integer" do
        subject{ int_instruction.new ["1","zu"] }
        it_behaves_like 'simple_instruction'
        its(:the_integer){ is_expected.to be_a(Integer).and be_zero }
      end
      context "without value" do
        subject{ int_instruction.new ["1"]  }
        it_behaves_like 'simple_instruction'
        its(:the_integer){ is_expected.to be_nil }
      end
      context "with Blank" do
        subject{ int_instruction.new ["1", ""]  }
        it_behaves_like 'simple_instruction'
        its(:the_integer){ is_expected.to be_nil }
      end
    end
    context "Instruction with String" do
      context "correct Behavior" do
        subject{ string_instruction.new ["1","zu"] }
        it_behaves_like 'simple_instruction'
        its(:the_string){ is_expected.to be_a(String).and eq("zu") }
      end
      context "false Integer" do
        subject{ string_instruction.new ["1","45"] }
        it_behaves_like 'simple_instruction'
        its(:the_string){ is_expected.to be_a(String).and eq("45") }
      end
      context "without value" do
        subject{ string_instruction.new ["1"]  }
        it_behaves_like 'simple_instruction'
        its(:the_string){ is_expected.to be_nil }
      end
      context "with Blank" do
        subject{ string_instruction.new ["1", ""]  }
        it_behaves_like 'simple_instruction'
        its(:the_string){ is_expected.to be_a(String).and be_empty }
      end
    end
    context "Instruction with Decimal" do
      context "correct Behavior" do
        subject{ decimal_instruction.new ["1","3.45"] }
        it_behaves_like 'simple_instruction'
        its(:the_decimal){ is_expected.to be_a(BigDecimal).and eq(3.45) }
      end
      context "false Integer" do
        subject{ decimal_instruction.new ["1","45"] }
        it_behaves_like 'simple_instruction'
        its(:the_decimal){ is_expected.to be_a(BigDecimal).and eq(45.0) }
      end
      context "without value" do
        subject{ decimal_instruction.new ["1"]  }
        it_behaves_like 'simple_instruction'
        its(:the_decimal){ is_expected.to be_nil }
      end
      context "with Blank" do
        subject{ decimal_instruction.new ["1", ""]  }
        it_behaves_like 'simple_instruction'
        its(:the_decimal){ is_expected.to be_nil }
      end
    end
    context "Instruction with Boolean" do
      context "correct true Behavior" do
        subject{ boolean_instruction.new ["1","1"] }
        it_behaves_like 'simple_instruction'
        its(:the_bool){ is_expected.to be_truthy }
      end
      context "correct false Behavior" do
        subject{ boolean_instruction.new ["1","0"] }
        it_behaves_like 'simple_instruction'
        its(:the_bool){ is_expected.to be_falsy }
      end
      context "false  String" do
        subject{ boolean_instruction.new ["1","Zted"] }
        it_behaves_like 'simple_instruction'
        its(:the_bool){ is_expected.to be_nil }
      end
      context "false  Integer" do
        subject{ boolean_instruction.new ["1","45"] }
        it_behaves_like 'simple_instruction'
        its(:the_bool){ is_expected.to be_nil }
      end
      context "without value" do
        subject{ boolean_instruction.new ["1"]  }
        it_behaves_like 'simple_instruction'
        its(:the_bool){ is_expected.to be_nil }
      end
      context "with Blank" do
        subject{ boolean_instruction.new ["1", ""]  }
        it_behaves_like 'simple_instruction'
        its(:the_bool){ is_expected.to be_nil }
      end
    end
    context "Instruction with Array" do
      context "correct empty Behavior" do
        subject{ array_instruction.new ["1","0"] }
        it_behaves_like 'simple_instruction'
        its(:the_array){ is_expected.to be_empty }
      end
      context "correct Behavior" do
        subject{ array_instruction.new ["1","2", "eins", "2"] }
        it_behaves_like 'simple_instruction'
        its(:the_array){ is_expected.to eq ["eins", '2'] }
      end
      context "false  String" do
        subject{ array_instruction.new ["1","Zted"] }   # perhaps request nil as answer?
        it_behaves_like 'simple_instruction'
        its(:the_array){ is_expected.to be_empty }
      end
      context "false  Integer" do
        subject{ array_instruction.new ["1","45"] }
        it_behaves_like 'simple_instruction'
        its(:the_array){ is_expected.to be_an(Array).and have(45).elements}
      end
      context "without value" do
        subject{ array_instruction.new ["1"]  }
        it_behaves_like 'simple_instruction'
        its(:the_array){ is_expected.to be_nil }
      end
      context "with Blank" do
        subject{ array_instruction.new ["1", ""]  }
        it_behaves_like 'simple_instruction'
        its(:the_array){ is_expected.to be_nil }
      end
    end
    context "Instruction with Hash" do
      context "correct empty Behavior" do
        subject{ hash_instruction.new ["1","0"] }
        it_behaves_like 'simple_instruction'
        its(:the_hash){ is_expected.to be_empty }
      end
      context "correct Behavior" do
        subject{ hash_instruction.new ["1","2", "eins", "2", "fuenf", "zurHeide"] }
        it_behaves_like 'simple_instruction'
        its(:the_hash){ is_expected.to eq :eins => '2', fuenf: 'zurHeide'  }
      end
      context "false  String" do
        subject{ hash_instruction.new ["1","Zted"] }   # perhaps request nil as answer?
        it_behaves_like 'simple_instruction'           # now: because of "abc".to_i = 0 an empty hash is  created
        its(:the_hash){ is_expected.to be_empty }
      end
      context "false  Integer" do
        subject{ hash_instruction.new ["1","45"] }
        it_behaves_like 'simple_instruction'
        its(:the_hash){ is_expected.to be_a(Hash).and be_empty}
      end
      context "without value" do
        subject{ hash_instruction.new ["1"]  }
        it_behaves_like 'simple_instruction'
        its(:the_hash){ is_expected.to be_nil }
      end
      context "with Blank" do
        subject{ hash_instruction.new ["1", ""]  }
        it_behaves_like 'simple_instruction'
        its(:the_hash){ is_expected.to be_nil }
      end
    end

  describe '#load_map' do
    let(:test_class) do
      Class.new(IB::Messages::Incoming::AbstractMessage) do
        @message_id = 1000
        @version = 1
        @data_map = []
      end
    end

    it 'handles Integer version condition (satisfied)' do
      msg = test_class.new(['1', 'world'])
      msg.load_map([1, [:cond_field, :string]])
      expect(msg.data[:cond_field]).to eq('world')
    end

    it 'handles Integer version condition (not satisfied)' do
      msg = test_class.new(['1', 'skipped'])
      msg.load_map([2, [:skip_field, :string]])
      expect(msg.data).not_to have_key(:skip_field)
    end

    it 'handles Proc condition (true)' do
      msg = test_class.new(['1', 'procval'])
      msg.load_map([proc { true }, [:proc_field, :string]])
      expect(msg.data[:proc_field]).to eq('procval')
    end

    it 'handles Proc condition (false)' do
      msg = test_class.new(['1', 'noval'])
      msg.load_map([proc { false }, [:no_field, :string]])
      expect(msg.data).not_to have_key(:no_field)
    end

    it 'handles true precondition' do
      msg = test_class.new(['1', 'trueval'])
      msg.load_map([true, [:true_field, :string]])
      expect(msg.data[:true_field]).to eq('trueval')
    end

    it 'handles false precondition' do
      msg = test_class.new(['1', 'falseval'])
      msg.load_map([false, [:false_field, :string]])
      expect(msg.data).not_to have_key(:false_field)
    end

    it 'handles nil precondition' do
      msg = test_class.new(['1', 'nilval'])
      msg.load_map([nil, [:nil_field, :string]])
      expect(msg.data).not_to have_key(:nil_field)
    end

    it 'handles grouped fields' do
      msg = test_class.new(['1', 'groupval'])
      msg.load_map([:group_name, :grouped_field, :string])
      expect(msg.data[:group_name][:grouped_field]).to eq('groupval')
    end

    it 'raises error on unrecognized instruction' do
      msg = test_class.new(['1'])
      expect { msg.load_map(['bad', 'instruction']) }.to raise_error(IB::Error, /Unrecognized instruction/)
    end

    it 'handles read error gracefully' do
      msg = test_class.new(['1'])
      expect { msg.load_map([:bad_field, :nonexistent_type]) }.to raise_error(IB::TransmissionError, /Reading/)
    end

    it 'handles version zero class load' do
      zclass = Class.new(IB::Messages::Incoming::AbstractMessage) do
        @message_id = 1000
        @version = 0
        @data_map = []
      end
      msg = zclass.new(['zeroval'])
      expect(msg.version).to be_nil
      msg.load_map([:zero_field, :string])
      expect(msg.data[:zero_field]).to eq('zeroval')
    end

    it 'handles simple_load rescue path' do
      bad_class = Class.new(IB::Messages::Incoming::AbstractMessage) do
        @message_id = 1000
        @version = 0
        @data_map = [['bad', 'instruction']]
      end
      expect { bad_class.new(['1']) }.to raise_error(IB::LoadError, /Unrecognized instruction/)
    end
  end
end
