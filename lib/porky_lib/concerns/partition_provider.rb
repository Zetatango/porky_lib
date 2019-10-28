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

        private

        def provider_info(record_attribute)
          raise ActiveRecord::RecordInvalid if partition_provider_attribute.nil?

          record = send(partition_provider_attribute)

          raise ActiveRecord::RecordInvalid unless record.present? && record.is_a?(PorkyLib::PartitionProvider)

          info = record.send(record_attribute)

          raise ActiveRecord::RecordInvalid if info.nil?

          info
        end
      end
    end
  end
end
