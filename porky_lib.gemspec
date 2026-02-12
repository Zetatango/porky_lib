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

  spec.required_ruby_version = '>= 3.3'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-kms'
  spec.add_dependency 'aws-sdk-s3'
  spec.add_dependency 'msgpack'
  spec.add_dependency 'rbnacl', '~> 7.1'
  spec.metadata = {
    'rubygems_mfa_required' => 'true'
  }
end
