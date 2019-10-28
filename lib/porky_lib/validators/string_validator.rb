# frozen_string_literal: true

require 'active_model'
require 'action_controller'

class PorkyLib::StringValidator < ActiveModel::Validator
  def validate(record)
    return if options[:fields].blank?

    options[:fields].each do |field|
      return false unless record.errors.messages.blank?

      sanitized_attr = ActionController::Base.helpers.sanitize(record[field])
      decoded_attr = Nokogiri::HTML.parse(sanitized_attr.to_s)
      record.errors[:field] << 'contains invalid characters...' unless record[field] == decoded_attr.text || record[field].blank?
    end
  end
end
