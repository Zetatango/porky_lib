# frozen_string_literal: true

require 'active_record'

class PorkyLib::ApplicationRecord < ActiveRecord::Base
  include PorkyLib::HasGuid

  self.abstract_class = true
end
