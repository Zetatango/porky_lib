# frozen_string_literal: true

require 'porky_lib'
require 'rails'

class PorkyLib::Railtie < Rails::Railtie
  rake_tasks do
    load 'tasks/db_tasks.rake'
  end
end
