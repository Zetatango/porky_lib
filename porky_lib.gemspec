# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'porky_lib/version'

Gem::Specification.new do |spec|
  spec.name          = "porky_lib"
  spec.version       = PorkyLib::VERSION
  spec.authors       = ["Greg Fletcher"]
  spec.email         = ["greg.fletcher@zetatango.com"]

  spec.summary       = 'A library for cryptographic services using AWS KMS and RbNaCl'
  spec.homepage      = 'https://github.com/Zetatango/porky_lib'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'aws-sdk-kms'
  spec.add_development_dependency 'aws-sdk-s3'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'bundler-audit'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'codacy-coverage'
  spec.add_development_dependency 'codecov'
  spec.add_development_dependency 'msgpack'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rbnacl', '=5.0.0'
  spec.add_development_dependency 'rbnacl-libsodium'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rspec-collection_matchers'
  spec.add_development_dependency 'rspec_junit_formatter'
  spec.add_development_dependency 'rspec-mocks'
  spec.add_development_dependency 'rubocop'
  spec.add_development_dependency 'rubocop-performance'
  spec.add_development_dependency 'rubocop-rspec'
  spec.add_development_dependency 'rubocop_runner'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'timecop'

  spec.add_dependency 'aws-sdk-kms'
  spec.add_dependency 'aws-sdk-s3'
  spec.add_dependency 'msgpack'
  spec.add_dependency 'rbnacl', '=5.0.0'
  spec.add_dependency 'rbnacl-libsodium'
end
