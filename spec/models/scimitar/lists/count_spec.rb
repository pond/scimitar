require 'spec_helper'

RSpec.describe Scimitar::Lists::Count do
  before :each do
    @instance = described_class.new
  end

  # ===========================================================================
  # LIMIT
  # ===========================================================================

  context '#limit' do
    it 'defaults to 100' do
      expect(@instance.limit).to eql(100)
    end

    it 'converts input strings to integers' do
      @instance.limit = '50'
      expect(@instance.limit).to eql(50)
    end

    it 'ignores "nil"' do
      expect { @instance.limit = nil }.to_not raise_error
      expect(@instance.limit).to eql(100)
    end

    it 'ignores blank' do
      expect { @instance.limit = ' ' }.to_not raise_error
      expect(@instance.limit).to eql(100)
    end

    context 'error checking' do
      it 'complains about attempts to set non-numeric values' do
        expect { @instance.limit = 'A' }.to raise_error(RuntimeError)
      end

      it 'allows count=0 per SCIM 2.0 specification (RFC 7644)' do
        expect { @instance.limit = '0' }.to_not raise_error
        expect(@instance.limit).to eql(0)
      end

      it 'allows count=0 as integer' do
        expect { @instance.limit = 0 }.to_not raise_error
        expect(@instance.limit).to eql(0)
      end

      it 'complains about attempts to set negative values' do
        expect { @instance.limit = '-10' }.to raise_error(RuntimeError)
      end
    end # "context 'on-read error checking' do"
  end # "context '#limit' do"

  # ===========================================================================
  # START INDEX
  # ===========================================================================

  context '#start_index' do
    it 'defaults to 1' do
      expect(@instance.start_index).to eql(1)
    end

    it 'accepts input integers' do
      @instance.start_index = 12
      expect(@instance.start_index).to eql(12)
    end

    it 'converts input strings to integers' do
      @instance.start_index = '12'
      expect(@instance.start_index).to eql(12)
    end

    it 'bounds zero values to 1' do
      @instance.start_index = '0'
      expect(@instance.start_index).to eql(1)
    end

    it 'ignores "nil"' do
      expect { @instance.start_index = nil }.to_not raise_error
      expect(@instance.start_index).to eql(1)
    end

    it 'ignores blank' do
      expect { @instance.start_index = ' ' }.to_not raise_error
      expect(@instance.start_index).to eql(1)
    end

    context 'error checking' do
      it 'complains about attempts to set non-numeric values' do

        expect { @instance.start_index = 'A' }.to raise_error(RuntimeError)
      end

      it 'complains about attempts to set negative values' do
        expect { @instance.start_index = '-10' }.to raise_error(RuntimeError)
      end
    end # "context 'on-read error checking' do"
  end # "context '#start_index' do"

  # ===========================================================================
  # OFFSET
  # ===========================================================================

  context '#offset' do
    it 'defaults to 0' do
      expect(@instance.offset).to eql(0)
    end

    it 'returns the #start_index minus one (set by integer)' do
      @instance.start_index = 12
      expect(@instance.offset).to eql(11)
    end

    it 'returns the #start_index minus one by (set by string)' do
      @instance.start_index = '12'
      expect(@instance.offset).to eql(11)
    end

    it 'is read-only' do
      expect { @instance.offset = 42 }.to raise_error(NoMethodError)
    end
  end # "context '#offset' do"

  # ===========================================================================
  # TOTAL
  # ===========================================================================

  context '#total' do
    it 'defaults to "nil" as "unknown"' do
      expect(@instance.total).to be_nil
    end

    it 'is read/write' do
      @instance.total = 42
      expect(@instance.total).to eql(42)
    end
  end # "context '#total' do"

  # ===========================================================================
  # INSTANTIATION
  # ===========================================================================

  context 'instantiation' do
    it 'instantiates with parameters' do
      instance = described_class.new(start_index: '5', total: 45)

      expect(instance.limit      ).to eql(100)
      expect(instance.start_index).to eql(5)
      expect(instance.offset     ).to eql(4)
      expect(instance.total      ).to eql(45)
    end
  end # "context 'instantiation' do"
end # "RSpec.describe Scimitar::Lists::Count do"
