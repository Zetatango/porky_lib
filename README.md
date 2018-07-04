Build Status: [![CircleCI](https://circleci.com/gh/Zetatango/porky_lib.svg?style=svg&circle-token=f1a41896097b814585e5042a8e38425b4d1cdc0b)](https://circleci.com/gh/Zetatango/porky_lib)

Code Coverage: [![codecov](https://codecov.io/gh/Zetatango/porky_lib/branch/master/graph/badge.svg?token=WxED9350q4)](https://codecov.io/gh/Zetatango/porky_lib)

# PorkyLib

This gem is a cryptographic services library. PorkyLib uses AWS Key Management Service (KMS) for key management and RbNaCl for
performing cryptographic operations.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'porky_lib'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install porky_lib

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `rspec` to run the tests without coverage or
`COVERAGE=true rspec` to run the tests with coverage.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number
in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags,
and push the `.gem` file to [rubygems.org](https://rubygems.org).
