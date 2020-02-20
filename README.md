[![CircleCI](https://circleci.com/gh/Zetatango/porky_lib.svg?style=svg&circle-token=f1a41896097b814585e5042a8e38425b4d1cdc0b)](https://circleci.com/gh/Zetatango/porky_lib) [![codecov](https://codecov.io/gh/Zetatango/porky_lib/branch/master/graph/badge.svg?token=WxED9350q4)](https://codecov.io/gh/Zetatango/porky_lib) [![Gem Version](https://badge.fury.io/rb/porky_lib.svg)](https://badge.fury.io/rb/porky_lib) [![Depfu](https://badges.depfu.com/badges/cbee343c363b7101657c0fc4bd5f551f/overview.svg)](https://depfu.com/github/Zetatango/porky_lib?project_id=6632)

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
max_file_size = 0 # max file size allowed, in bytes - defaults to 0
presign_url_expires_in = 300 # expiry time for presigned urls, in seconds - defaults to 300 (5 minutes)
PorkyLib::Config.configure(aws_region: ENV[AWS_REGION],
                           aws_key_id: ENV[AWS_KEY_ID],
                           aws_key_secret: ENV[AWS_KEY_SECRET],
                           aws_client_mock: use_mock_client,
                           max_file_size: max_file_size,
                           presign_url_expires_in: presign_url_expires_in)
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

To encrypt data with a known plaintext key:
```ruby
# Where plaintext is the data to encrypt
# plaintext_key is the encryption key to use
# encryption_info is the structure returned that contains:
#   ciphertext: plaintext encrypted under plaintext_key
#   nonce: The generated nonce
encryption_info = PorkyLib::Symmetric.instance.encrypt_with_key(plaintext, plaintext_key)
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

To decrypt data with a known plaintext key:
```ruby
# Where ciphertext is the encrypted data to be decrypted
# plaintext_key is the decryption key to use
# nonce is the nonce to use
# decryption_info is the structured returned that contains:
#   plaintext: ciphertext decrypted under plaintext_key
decryption_info = PorkyLib::Symmetric.instance.decrypt_with_key(ciphertext, plaintext_key, nonce)
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

### Securely Deleting Plaintext Key From Memory
To securely delete the plaintext key from memory:
```ruby
# Where length is the number of bytes of the plaintext key (i.e. plaintext_key.bytesize)
plaintext_key.replace(PorkyLib::Symmetric.instance.secure_delete_plaintext_key(plaintext_key.bytesize))
```

### Check If An Alias Exists
To verify whether an alias exists or not:
```ruby
# Where key_alias is the alias name to verify
alias_exists = PorkyLib::Symmetric.instance.cmk_alias_exists?(key_alias)
```

### To Read From AWS S3
```ruby
# Where bucket_name is the name of the S3 bucket to read from
# file_key is file identifier of the file/data that was written to S3.
file_data = PorkyLib::FileService.read(bucket_name, file_key)
```

### To Read Unencrypted Files From AWS S3
```ruby
# Where bucket_name is the name of the S3 bucket to read from
# file_key is file identifier of the file/data that was written to S3.
file_data = PorkyLib::Unencrypted::FileService.read(bucket_name, file_key)
```

### To Write To AWS S3
```ruby
# --- DEPRECATED --- Please use write_data or write_file instead of write
# Where file is the data to encrypt and upload to S3 (can be a path or raw data or ruby file object)
# bucket_name is the name of the S3 bucket to write to
# key_id is the ID of the CMK to use to generate a data encryption key to encrypt the file data
# options is an optional parameter for specifying optional metadata about the file and the storage_class of the object
file_key = PorkyLib::FileService.write(file, bucket_name, key_id, options)
```

### To Write Files To AWS S3
```ruby
# Where file is the data to encrypt and upload to S3 (can be a path or ruby file object)
# bucket_name is the name of the S3 bucket to write to
# key_id is the ID of the CMK to use to generate a data encryption key to encrypt the file data
# options is an optional parameter for specifying optional metadata about the file and the storage_class of the object
file_key = PorkyLib::FileService.write_file(file, bucket_name, key_id, options)
```

### To Write Data To AWS S3
```ruby
# Where data is the raw data to encrypt and upload to S3
# bucket_name is the name of the S3 bucket to write to
# key_id is the ID of the CMK to use to generate a data encryption key to encrypt the file data
# options is an optional parameter for specifying optional metadata about the file and the storage_class of the object
file_key = PorkyLib::FileService.write_data(data, bucket_name, key_id, options)
```

### To Write Unencrypted To AWS S3
```ruby
# --- DEPRECATED --- Please use write_data or write_file instead of write
# Where file is the data to upload to S3 (can be a path or raw data or ruby file object)
# bucket_name is the name of the S3 bucket to write to
# options is an optional parameter for specifying optional metadata about the file and the storage_class of the object
file_key = PorkyLib::Unencrypted::FileService.write(file, bucket_name, options)
```

### To Write Unencrypted Files To AWS S3
```ruby
# Where file is the data to encrypt and upload to S3 (can be a path or ruby file object)
# bucket_name is the name of the S3 bucket to write to
# options is an optional parameter for specifying optional metadata about the file and the storage_class of the object
file_key = PorkyLib::Unencrypted::FileService.write_file(file, bucket_name, options)
```

### To Write Unencrypted Data To AWS S3
```ruby
# Where data is the raw data to encrypt and upload to S3
# bucket_name is the name of the S3 bucket to write to
# options is an optional parameter for specifying optional metadata about the file and the storage_class of the object
file_key = PorkyLib::Unencrypted::FileService.write_data(data, bucket_name, options)
```

### Generate S3 Presigned POST URL
To generate a new presigned POST url (used to upload files directly to AWS S3):
```ruby
# Where bucket_name is the name of the S3 bucket to write to
# options is an optional parameter for specifying optional metadata about the file
# file_key is randomly generated, unless it's passed as a parameter in the options hash using 'file_name' as key
url, file_key = PorkyLib::Symmetric.instance.presigned_post_url(bucket_name, options)
```

### Generate S3 Presigned GET URL
To generate a new presigned GET url (used to download files directly from AWS S3):
```ruby
# Where bucket_name is the name of the S3 bucket to read from
# file_key is the file identifier of the file/data that was written to S3.
url = PorkyLib::Symmetric.instance.presigned_get_url(bucket_name, file_key)
```

## Rake task
If you want to write or read an encrypted file from the command line, there is a Rake write and read task.

> Note: the environment variables can be set globally or by prepending them to the rake task command

### Write file

Rake task name: `file:write`

Environment variables:
* Required
  * `FILE_PATH` - Absolute or relative file path
  * `CMK_KEY_ID` - Alias of the CMK key
  * `AWS_S3_BUCKET` - AWS S3 bucket name
  * `AWS_REGION` - AWS region name
  * `AWS_ACCESS_KEY_ID` - AWS access key ID (credentials)
  * `AWS_ACCESS_KEY` - AWS secret access key (credentials)
* Optional
  * `AWS_S3_MOCK_CLIENT` - PorkyLib's AWS KMS mock client (defaults to `true`)
  * `AWS_S3_MAX_FILE_SIZE` - Max file size (defaults to `1MB`)
  * `AWS_S3_STORAGE_CLASS` - One of STANDARD, REDUCED_REDUNDANCY, STANDARD_IA, ONEZONE_IA, INTELLIGENT_TIERING, GLACIER, DEEP_ARCHIVE (defaults to `STANDARD`)
  * `AWS_S3_KEEP_FILE_NAME` - Saves the file in AWS S3 with the original file name (defaults to `true`)

### Read file

Rake task name: `file:read`

Environment variables:
* Required
  * `FILE_KEY` - AWS S3 object file key
  * `AWS_S3_BUCKET` - AWS S3 bucket name
  * `AWS_REGION` - AWS region name
  * `AWS_ACCESS_KEY_ID` - AWS access key ID (credentials)
  * `AWS_ACCESS_KEY` - AWS secret access key (credentials)
* Optional
  * `AWS_S3_MOCK_CLIENT` - PorkyLib's AWS KMS mock client (defaults to `true`)
  * `AWS_S3_MAX_FILE_SIZE` - Max file size (defaults to `1MB`)
  * `DESTINATION` - Location to save the file (defaults to `FILE_KEY`)

## Development

Development on this project should occur on separate feature branches and pull requests should be submitted. When submitting a
pull request, the pull request comment template should be filled out as much as possible to ensure a quick review and increase
the likelihood of the pull request being accepted.

### Ruby

This application requires:

*   Ruby version: 2.7.0

If you do not have Ruby installed, it is recommended you use ruby-install and chruby to manage Ruby versions.

```bash
brew install ruby-install chruby
ruby-install ruby 2.7.0
```

Add the following lines to ~/.bash_profile:

```bash
source /usr/local/opt/chruby/share/chruby/chruby.sh
source /usr/local/opt/chruby/share/chruby/auto.sh
```

Set Ruby version to 2.7.0:

```bash
source ~/.bash_profile
chruby 2.7.0
```

### Running Tests

```ruby
rspec # Without code coverage
COVERAGE=true rspec # with code coverage
```

## Contributing

Bug reports and pull requests are welcome on GitHub at [https://github.com/Zetatango/porky_lib](https://github.com/Zetatango/porky_lib)
