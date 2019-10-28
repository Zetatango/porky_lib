# frozen_string_literal: true

require 'active_record'

class PorkyLib::ApplicationRecord < ActiveRecord::Base
  include PorkyLib::HasGuid

  self.abstract_class = true

  def entity
    "#{self.class.name}s::#{self.class.name}Entity".constantize.new(self)
  end
end
