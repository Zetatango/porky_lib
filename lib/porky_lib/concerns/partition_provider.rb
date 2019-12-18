# frozen_string_literal: true

module PorkyLib::PartitionProvider
  extend ActiveSupport::Concern

  class_methods do
    def partition_provider(attribute)
      class_eval do
        cattr_accessor :partition_provider_attribute do
          attribute
        end

        def provider_partition_guid
          provider_info(:provider_partition_guid)
        end

        def provider_encryption_epoch
          provider_info(:provider_encryption_epoch)
        end
      end
    end

    def partition_provider_guid(guid_method, model)
      class_eval do
        cattr_accessor :model do
          model
        end

        cattr_accessor :guid_method do
          guid_method
        end

        def provider_partition_guid
          provider_record_info(:provider_partition_guid, record)
        end

        def provider_encryption_epoch
          provider_record_info(:provider_encryption_epoch, record)
        end

        private

        def record
          model.find_by(guid: send(guid_method))
        end
      end
    end
  end

  def provider_info(record_attribute)
    raise ActiveRecord::RecordInvalid if partition_provider_attribute.nil?

    provider_record_info(record_attribute, send(partition_provider_attribute))
  end

  private

  def provider_record_info(record_attribute, record)
    raise ActiveRecord::RecordInvalid unless record.present? && record.is_a?(PorkyLib::PartitionProvider)

    info = record.send(record_attribute)

    raise ActiveRecord::RecordInvalid if info.nil?

    info
  end
end
