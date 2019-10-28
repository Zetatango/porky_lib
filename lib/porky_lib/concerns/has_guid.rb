# frozen_string_literal: true

require 'activerecord-rescue_from_duplicate'

module PorkyLib::HasGuid
  extend ActiveSupport::Concern

  REGEXP = /^[\w]+_[\w]+$/.freeze

  mattr_accessor :registry do
    {}
  end

  class_methods do
    # rubocop:disable Naming/PredicateName

    def has_guid(prefix)
      if PorkyLib::HasGuid.registry[prefix].present?
        raise ArgumentError, "Prefix #{prefix} has already been registered by class #{PorkyLib::HasGuid.registry[prefix]}"
      end

      PorkyLib::HasGuid.registry[prefix] = self

      class_eval do
        cattr_accessor :has_guid_prefix do
          prefix
        end

        rescue_from_duplicate :guid
        before_create :generate_guid
        validate :ensure_guid_does_not_change

        def dup
          super.tap { |duplicate| duplicate.guid = nil if duplicate.respond_to?('guid=') }
        end

        def to_param
          guid.to_param
        end

        def self.generate_guid
          "#{has_guid_prefix}_#{SecureRandom.base58(16)}"
        end

        def generate_guid
          self.guid = guid.presence || self.class.generate_guid
        end

        def self.validation_regexp
          /^#{has_guid_prefix}_[\w]+$/
        end

        def ensure_guid_does_not_change
          return if new_record?
          return unless guid_changed?

          errors.add(:guid, 'cannot be changed for persisted records')
        end
      end
    end
    # rubocop:enable Naming/PredicateName
  end
end
