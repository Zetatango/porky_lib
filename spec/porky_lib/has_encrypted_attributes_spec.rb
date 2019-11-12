# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::HasEncryptedAttributes do
  describe 'when a subclass does not implement the HasEncryptedAttributes abstract methods' do
    let(:not_implemented_class) do
      Class.new(PorkyLib::EncryptionKey) do
        include PorkyLib::HasEncryptedAttributes
      end
    end

    it 'raises a NoMethodError when partition_guid is not implemented' do
      expect { not_implemented_class.new.generate_partition_guid }.to raise_exception(NoMethodError)
    end

    it 'raises a NoMethodError when encryption_epoch is not implemented' do
      expect { not_implemented_class.new.generate_encryption_epoch }.to raise_exception(NoMethodError)
    end
  end

  describe 'when a subclass does implement the HasEncryptedAttributes abstract methods' do
    it 'does not raise a NoMethodError when generate_partition_guid is implemented' do
      user = create :user
      expect { user.generate_partition_guid }.not_to raise_error
    end

    it 'does not raise a NoMethodError when generate_encryption_epoch is implemented' do
      user = create :user
      expect { user.generate_encryption_epoch }.not_to raise_error
    end
  end
end
