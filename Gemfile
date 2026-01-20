# frozen_string_literal: true

ruby '3.2.5'

source "https://rubygems.org"

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

# Specify your gem's dependencies in porky_lib.gemspec
gemspec

# add development dependencies
group :development, :test do
  gem 'bundler'
  gem 'bundler-audit'
  gem 'byebug'
  gem 'codacy-coverage'
  gem 'codecov'
  gem 'rake'
  gem 'rspec'
  gem 'rspec-collection_matchers'
  gem 'rspec_junit_formatter'
  gem 'rspec-mocks'
  gem 'rubocop'
  gem 'rubocop-performance'
  gem 'rubocop-rspec'
  gem 'rubocop_runner'
  gem 'simplecov'
  gem 'timecop'
end
