[![CircleCI](https://circleci.com/gh/Zetatango/porky_lib.svg?style=svg&circle-token=f1a41896097b814585e5042a8e38425b4d1cdc0b)](https://circleci.com/gh/Zetatango/porky_lib) [![codecov](https://codecov.io/gh/Zetatango/porky_lib/branch/master/graph/badge.svg?token=WxED9350q4)](https://codecov.io/gh/Zetatango/porky_lib)

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
    
Inside of your Ruby program do:

```ruby
require 'porky_lib'
```
... to pull it in as a dependency.

## Usage

### Initialization
Something like the following should be included in an initializer in your Rails project:
```ruby
# Use PorkyLib's AWS KMS mock client except in production, for example
use_mock_client = !Rails.env.production?
PorkyLib::Config.configure(aws_region: ENV[AWS_REGION],
                           aws_key_id: ENV[AWS_KEY_ID],
                           aws_key_secret: ENV[AWS_KEY_SECRET],
                           aws_client_mock: use_mock_client)
PorkyLib::Config.initialize_aws
```

### Creating a New CMK
To create a new customer master key (CMK) within AWS:
```ruby
# Where tags is a list of key/value pairs (i.e [{ key1: 'value1' }])
# key_alias is an optional parameter, and if provided will create an alias with the provided value for the newly created key
# key_rotation_enabled is an optional parameter, and if true will enable automatic key rotation for the new created key. Default is true.
key_id = PorkyLib::Symmetric.instance.create_key(tags, key_alias, key_rotation_enabled)
```

### Creating an Alias for an Existing CMK
To create a new alias for an existing customer master key (CMK) within AWS:
```ruby
# Where key_id is the AWS key ID or Amazon Resource Name (ARN)
# key_alias is the value of the alias to create
PorkyLib::Symmetric.instance.create_alias(key_id, key_alias)
```

### Enabling Key Rotation for an Existing CMK
To create a new alias for an existing customer master key (CMK) within AWS:
```ruby
# Where key_id is the AWS key ID or Amazon Resource Name (ARN)
PorkyLib::Symmetric.instance.enable_key_rotation(key_id)
```

### Encrypting Data
To encrypt data:
```ruby
# Where data is the data to encrypt
# cmk_key_id is the AWS key ID, Amazon Resource Name (ARN) or alias for the CMK to use to generate the data encryption key (DEK)
# ciphertext_dek is an optional parameter to specify the data encryption key to use to encrypt the data. If not provided, a new data encryption key will be generated. Default is nil.
# encryption_context is an optional parameter to provide additional authentication data for encrypting the DEK. Default is nil.
[ciphertext_dek, ciphertext, nonce] = PorkyLib::Symmetric.instance.encrypt(data, cmk_key_id, ciphertext_dek, encryption_context)
```

### Decrypting Data
To decrypt data:
```ruby
# Where ciphertext_dek is the encrypted data encryption key (DEK)
# ciphertext is the encrypted data to be decrypted
# nonce is the nonce value associated with ciphertext
# encryption_context is an optional parameter to provide additional authentication data for decrypting the DEK. Default is nil. Note, this must match the value that was used to encrypt.
plaintext_data = PorkyLib::Symmetric.instance.decrypt(ciphertext_dek, ciphertext, nonce, encryption_context)
```

### Generating Data Encryption Keys
To generate a new data encryption key:
```ruby
# Where cmk_key_id is the AWS key ID, Amazon Resource Name (ARN) or alias for the CMK to use to generate the data encryption key (DEK)
# encryption_context is an optional parameter to provide additional authentication data for encrypting the DEK. Default is nil.
plaintext_key, ciphertext_key = PorkyLib::Symmetric.instance.generate_data_encryption_key(cmk_key_id, encryption_context)
```

### Decrypting Data Encryption Keys
To decrypt an existing ciphertext data encryption key:
```ruby
# Where ciphertext_key is the data encryption key, encrypted by a CMK within your AWS environment.
# encryption_context is an optional parameter to provide additional authentication data for encrypting the DEK. Default is nil.
plaintext_key = PorkyLib::Symmetric.instance.generate_data_encryption_key(ciphertext_key, encryption_context)
```

## Development

Development on this project should occur on separate feature branches and pull requests should be submitted. When submitting a
pull request, the pull request comment template should be filled out as much as possible to ensure a quick review and increase
the likelihood of the pull request being accepted.

### Running Tests

```ruby
rspec # Without code coverage
COVERAGE=true rspec # with code coverage
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/Zetatango/porky_lib](https://github.com/Zetatango/porky_lib)
