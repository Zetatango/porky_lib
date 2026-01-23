# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::Symmetric, type: :request do
  let(:symmetric) { described_class.instance }
  let(:default_config) do
    { aws_region: 'us-east-1',
      aws_key_id: 'abc123',
      aws_key_secret: 'def456' }
  end
  let(:plaintext_data) { 'abc123' }
  let(:default_tags) do
    [
      { key1: 'value 1' },
      { key2: 'value 2' }
    ]
  end
  let(:default_key_id) { 'alias/zetatango' }
  let(:default_encryption_context) do
    {
      encryptionContextKey: 'encryption context value'
    }
  end
  let(:bad_key_id) { 'alias/bad_key' }
  let(:bad_tags) do
    [
      { key1: 'bad_value' }
    ]
  end
  let(:key_alias) { 'alias/new_key' }
  let(:bad_alias) { 'alias/aws' }
  let(:dup_alias) { 'alias/dup' }
  let(:bad_encryption_context) do
    {
      encryptionContextKey: 'bad encryption context'
    }
  end
  let(:data_encryption_key_length) { 256 / 8 } # 256-bit key in bytes

  before do
    PorkyLib::Config.configure(default_config)
    PorkyLib::Config.initialize_aws
  end

  def encrypt_with_bad_key
    box = RbNaCl::SecretBox.new(("\0" * data_encryption_key_length).b)
    nonce = RbNaCl::Random.random_bytes(box.nonce_bytes)
    ciphertext = box.encrypt(nonce, plaintext_data)

    [ciphertext, nonce]
  end

  shared_examples_for 'Encrypt and decrypt with key tests' do
    it 'Encrypt returns non-null values for ciphertext and nonce' do
      encryption_info = symmetric.send(encrypt_function, data, plaintext_key)

      expect(encryption_info.ciphertext).not_to be_nil
      expect(encryption_info.nonce).not_to be_nil
    end

    it 'Decrypt returns an expected value' do
      encryption_info = symmetric.send(encrypt_function, data, plaintext_key)
      decryption_info = symmetric.send(decrypt_function, encryption_info.ciphertext, plaintext_key, encryption_info.nonce)
      expect(decryption_info.plaintext).to eq(data)
    end

    it 'Decrypt with bad nonce raises CryptoError' do
      encryption_info = symmetric.send(encrypt_function, data, plaintext_key)
      expect do
        symmetric.send(decrypt_function, encryption_info.ciphertext, plaintext_key, SecureRandom.hex(12))
      end.to raise_error(RbNaCl::CryptoError)
    end

    it 'Decrypt with bad ciphertext data raises CryptoError' do
      encryption_info = symmetric.send(encrypt_function, data, plaintext_key)
      expect do
        symmetric.send(decrypt_function, SecureRandom.base64(32), plaintext_key, encryption_info.nonce)
      end.to raise_error(RbNaCl::CryptoError)
    end

    it 'Decrypt with slightly modified data raises CryptoError' do
      encryption_info = symmetric.send(encrypt_function, data, plaintext_key)
      data_bytes = encryption_info.ciphertext.unpack('c*')
      data_bytes[0] = data_bytes[0] + 1
      data = data_bytes.pack('c*')
      expect do
        symmetric.send(decrypt_function, data, plaintext_key, encryption_info.nonce)
      end.to raise_error(RbNaCl::CryptoError)
    end
  end

  shared_examples_for 'Encrypt and decrypt tests' do
    it 'Encrypt returns non-null values for ciphertext key, ciphertext data, and nonce' do
      key, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id, nil, default_encryption_context)
      expect(key).not_to be_nil
      expect(data).not_to be_nil
      expect(nonce).not_to be_nil
    end

    it 'Encrypt returns non-null values for ciphertext key, ciphertext data, and nonce with existing data encryption key' do
      _, ciphertext_key = symmetric.generate_data_encryption_key(default_key_id, default_encryption_context)
      key, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id, ciphertext_key, default_encryption_context)
      expect(key).to eq(ciphertext_key)
      expect(data).not_to be_nil
      expect(nonce).not_to be_nil
    end

    it 'Encrypt returns non-null values with no encryption context for ciphertext key, ciphertext data, and nonce' do
      key, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id)
      expect(key).not_to be_nil
      expect(data).not_to be_nil
      expect(nonce).not_to be_nil
    end

    it 'Encrypt with bad CMK key ID raises NotFoundException' do
      expect do
        symmetric.send(encrypt_function, plaintext_data, bad_key_id, nil, default_encryption_context)
      end.to raise_error(Aws::KMS::Errors::NotFoundException)
    end

    it 'Decrypt returns an expected value' do
      key, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id, nil, default_encryption_context)
      result, should_reencrypt = symmetric.send(decrypt_function, key, data, nonce, default_encryption_context)
      expect(result).to eq(plaintext_data)
      expect(should_reencrypt).to be_falsey
    end

    it 'Decrypt with no encryption context returns an expected value' do
      key, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id)
      result, should_reencrypt = symmetric.send(decrypt_function, key, data, nonce, nil)
      expect(result).to eq(plaintext_data)
      expect(should_reencrypt).to be_falsey
    end

    it 'Decrypt with bad nonce raises CryptoError' do
      key, data, = symmetric.send(encrypt_function, plaintext_data, default_key_id, nil, default_encryption_context)
      expect do
        symmetric.send(decrypt_function, key, data, SecureRandom.hex(12), default_encryption_context)
      end.to raise_error(RbNaCl::CryptoError)
    end

    it 'Decrypt with bad encryption context raises InvalidCiphertextException' do
      key, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id, nil, default_encryption_context)
      expect do
        symmetric.send(decrypt_function, key, data, nonce, bad_encryption_context)
      end.to raise_error(Aws::KMS::Errors::InvalidCiphertextException)
    end

    it 'Decrypt with bad ciphertext data raises CryptoError' do
      key, _, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id, nil, default_encryption_context)
      expect do
        symmetric.send(decrypt_function, key, SecureRandom.base64(data_encryption_key_length), nonce, default_encryption_context)
      end.to raise_error(RbNaCl::CryptoError)
    end

    it 'Decrypt with slightly modified data raises CryptoError' do
      key, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id, nil, default_encryption_context)
      data_bytes = data.unpack('c*')
      data_bytes[0] = data_bytes[0] + 1
      data = data_bytes.pack('c*')
      expect do
        symmetric.send(decrypt_function, key, data, nonce, default_encryption_context)
      end.to raise_error(RbNaCl::CryptoError)
    end

    it 'Decrypt with bad ciphertext key raises InvalidCiphertextException' do
      _, data, nonce = symmetric.send(encrypt_function, plaintext_data, default_key_id, nil, default_encryption_context)
      expect do
        symmetric.send(decrypt_function, SecureRandom.base64(data_encryption_key_length), data, nonce, default_encryption_context)
      end.to raise_error(Aws::KMS::Errors::InvalidCiphertextException)
    end

    it 'If data was encrypted incorrectly, decrypt and mark as should re-encrypt' do
      ciphertext, nonce = encrypt_with_bad_key
      message, should_reencrypt = symmetric.send(decrypt_function, [nil, nil, SecureRandom.random_bytes(data_encryption_key_length)].to_msgpack.reverse,
                                                 ciphertext, nonce, nil)
      expect(message).to eq(plaintext_data)
      expect(should_reencrypt).to be_truthy
    end
  end

  describe 'for base encrypt and decrypt' do
    include_examples 'Encrypt and decrypt tests' do
      let(:encrypt_function) { :encrypt }
      let(:decrypt_function) { :decrypt }
    end
  end

  describe 'for benchmarked encrypt and decrypt' do
    include_examples 'Encrypt and decrypt tests' do
      let(:encrypt_function) { :encrypt_with_benchmark }
      let(:decrypt_function) { :decrypt_with_benchmark }
    end
  end

  it 'Generate data encryption key returns non-null values for plaintext_key and ciphertext_key' do
    plaintext_key, ciphertext_key = symmetric.generate_data_encryption_key(default_key_id, default_encryption_context)
    expect(plaintext_key).not_to be_nil
    expect(ciphertext_key).not_to be_nil
  end

  it 'Generate data encryption key with bad CMK key ID raises NotFoundException' do
    expect do
      symmetric.generate_data_encryption_key(bad_key_id, default_encryption_context)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Create key returns non-null value for key ID' do
    key_id = symmetric.create_key(default_tags, key_alias)
    expect(key_id).not_to be_nil
  end

  it 'Create key raises TagException for invalid tags' do
    expect do
      symmetric.create_key(bad_tags, key_alias)
    end.to raise_error(Aws::KMS::Errors::TagException)
  end

  it 'Create key raises InvalidAliasNameException for invalid alias name' do
    expect do
      symmetric.create_key(default_tags, bad_alias)
    end.to raise_error(Aws::KMS::Errors::InvalidAliasNameException)
  end

  it 'Create key raises AlreadyExistsException for duplicate alias name' do
    expect do
      symmetric.create_key(default_tags, dup_alias)
    end.to raise_error(Aws::KMS::Errors::AlreadyExistsException)
  end

  it 'Create alias raise NotFoundException for unknown CMK key id' do
    expect do
      symmetric.create_alias(bad_key_id, key_alias)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Enable key rotation raise NotFoundException for unknown CMK key id' do
    expect do
      symmetric.enable_key_rotation(bad_key_id)
    end.to raise_error(Aws::KMS::Errors::NotFoundException)
  end

  it 'Securely deleting plaintext key returns a string of null characters matching the length of the key' do
    plaintext_key, = symmetric.generate_data_encryption_key(default_key_id, default_encryption_context)
    obj_id = plaintext_key.object_id
    plaintext_key.replace(symmetric.secure_delete_plaintext_key(plaintext_key.bytesize))
    expect(plaintext_key).to eq("\0" * data_encryption_key_length)
    expect(plaintext_key.object_id).to eq(obj_id)
    expect(ObjectSpace._id2ref(plaintext_key.object_id)).to eq("\0" * data_encryption_key_length)
  end

  it 'Alias exists returns true if a given CMK alias already exists' do
    expect(symmetric.cmk_alias_exists?(key_alias)).to be true
  end

  it 'Alias exists returns false if a given CMK alias does not already exist' do
    expect(symmetric.cmk_alias_exists?(bad_alias)).to be false
  end

  it 'Using mock client in test environment' do
    expect(symmetric.client.inspect).to eq('#<Aws::KMS::Client (mocked)>')
  end

  describe 'edge cases for data sizes' do
    it 'encrypts and decrypts empty string' do
      empty_data = ''
      key, ciphertext, nonce = symmetric.encrypt(empty_data, default_key_id)
      plaintext, = symmetric.decrypt(key, ciphertext, nonce)
      expect(plaintext).to eq(empty_data)
    end

    it 'encrypts and decrypts single character' do
      single_char = 'a'
      key, ciphertext, nonce = symmetric.encrypt(single_char, default_key_id)
      plaintext, = symmetric.decrypt(key, ciphertext, nonce)
      expect(plaintext).to eq(single_char)
    end

    it 'encrypts and decrypts single byte' do
      single_byte = "\x00"
      key, ciphertext, nonce = symmetric.encrypt(single_byte, default_key_id)
      plaintext, = symmetric.decrypt(key, ciphertext, nonce)
      expect(plaintext).to eq(single_byte)
    end

    it 'encrypts and decrypts data with null bytes' do
      data_with_nulls = "hello\x00world\x00test"
      key, ciphertext, nonce = symmetric.encrypt(data_with_nulls, default_key_id)
      plaintext, = symmetric.decrypt(key, ciphertext, nonce)
      expect(plaintext).to eq(data_with_nulls)
    end

    it 'encrypts and decrypts binary data' do
      binary_data = (0..255).map(&:chr).join
      key, ciphertext, nonce = symmetric.encrypt(binary_data, default_key_id)
      plaintext, = symmetric.decrypt(key, ciphertext, nonce)
      expect(plaintext.bytes).to eq(binary_data.bytes)
    end

    it 'encrypts and decrypts unicode data' do
      unicode_data = '日本語テスト 🎉 مرحبا'
      key, ciphertext, nonce = symmetric.encrypt(unicode_data, default_key_id)
      plaintext, = symmetric.decrypt(key, ciphertext, nonce)
      expect(plaintext.force_encoding('UTF-8')).to eq(unicode_data)
    end

    it 'encrypts and decrypts whitespace-only data' do
      whitespace_data = "   \t\n\r  "
      key, ciphertext, nonce = symmetric.encrypt(whitespace_data, default_key_id)
      plaintext, = symmetric.decrypt(key, ciphertext, nonce)
      expect(plaintext).to eq(whitespace_data)
    end
  end

  # rubocop:disable RSpec/ExampleLength
  describe 'thread safety' do
    it 'returns the same instance from multiple threads' do
      instances = []
      threads = Array.new(10) do
        Thread.new { instances << described_class.instance }
      end
      threads.each(&:join)

      expect(instances.uniq.size).to eq(1)
      expect(instances.all? { |i| i.equal?(described_class.instance) }).to be true
    end

    it 'handles concurrent encrypt operations' do
      results = []
      threads = Array.new(5) do |i|
        Thread.new do
          data = "test_data_#{i}"
          key, ciphertext, nonce = symmetric.encrypt(data, default_key_id)
          results << { key:, ciphertext:, nonce:, original: data }
        end
      end
      threads.each(&:join)

      expect(results.size).to eq(5)
      results.each do |result|
        plaintext, = symmetric.decrypt(result[:key], result[:ciphertext], result[:nonce])
        expect(plaintext).to eq(result[:original])
      end
    end

    it 'handles concurrent decrypt operations' do
      # Pre-encrypt data
      encrypted_data = Array.new(5) do |i|
        data = "test_data_#{i}"
        key, ciphertext, nonce = symmetric.encrypt(data, default_key_id)
        { key:, ciphertext:, nonce:, original: data }
      end

      results = []
      threads = encrypted_data.map do |data|
        Thread.new do
          plaintext, = symmetric.decrypt(data[:key], data[:ciphertext], data[:nonce])
          results << { plaintext:, expected: data[:original] }
        end
      end
      threads.each(&:join)

      expect(results.size).to eq(5)
      results.each do |result|
        expect(result[:plaintext]).to eq(result[:expected])
      end
    end
  end
  # rubocop:enable RSpec/ExampleLength

  # rubocop:disable RSpec/MultipleExpectations
  describe 'for #encrypt_with_benchmark' do
    it 'returns encryption statistics' do
      key, data, nonce, stats = symmetric.encrypt_with_benchmark(plaintext_data, default_key_id, nil, nil)
      expect(key).not_to be_nil
      expect(data).not_to be_nil
      expect(nonce).not_to be_nil
      expect(stats).not_to be_nil

      expect(stats).to have_key(:generate_key)
      expect(stats).not_to have_key(:decrypt_key)
      expect(stats).to have_key(:encrypt)
      expect(stats).to have_key(:clear_key)
    end

    it 'returns encryption statistics (passed in dek)' do
      _, ciphertext_key = symmetric.generate_data_encryption_key(default_key_id, default_encryption_context)
      key, data, nonce, stats = symmetric.encrypt_with_benchmark(plaintext_data, default_key_id, ciphertext_key, default_encryption_context)
      expect(key).to eq(ciphertext_key)
      expect(data).not_to be_nil
      expect(nonce).not_to be_nil
      expect(stats).not_to be_nil

      expect(stats).not_to have_key(:generate_key)
      expect(stats).to have_key(:decrypt_key)
      expect(stats).to have_key(:encrypt)
      expect(stats).to have_key(:clear_key)
    end
  end

  describe 'for #decrypt_with_benchmark' do
    it 'returns encryption statistics when track_statistics is set' do
      key, data, nonce = symmetric.encrypt_with_benchmark(plaintext_data, default_key_id, nil, default_encryption_context)
      result, should_reencrypt, stats = symmetric.decrypt_with_benchmark(key, data, nonce, default_encryption_context)
      expect(result).to eq(plaintext_data)
      expect(should_reencrypt).to be_falsey
      expect(stats).not_to be_nil

      expect(stats).to have_key(:decrypt_key)
      expect(stats).to have_key(:decrypt)
      expect(stats).to have_key(:clear_key)
    end

    it 'raises exception on decrypt_with_benchmark failure when track_statistics is set' do
      key, data, = symmetric.encrypt_with_benchmark(plaintext_data, default_key_id, nil, default_encryption_context)
      expect do
        symmetric.decrypt_with_benchmark(key, data, SecureRandom.hex(12), default_encryption_context)
      end.to raise_error(RbNaCl::CryptoError)
    end
  end
  # rubocop:enable RSpec/MultipleExpectations

  describe 'Encryption with a given key' do
    let(:plaintext_key) { RbNaCl::Random.random_bytes(RbNaCl::SecretBox.key_bytes) }
    let(:data) { SecureRandom.base64(32) }

    include_examples 'Encrypt and decrypt with key tests' do
      let(:encrypt_function) { :encrypt_with_key_with_benchmark }
      let(:decrypt_function) { :decrypt_with_key_with_benchmark }
    end

    include_examples 'Encrypt and decrypt with key tests' do
      let(:encrypt_function) { :encrypt_with_key }
      let(:decrypt_function) { :decrypt_with_key }
    end

    describe '#encrypt_with_key_with_benchmark' do
      it 'returns encryption statistics' do
        encryption_info = symmetric.encrypt_with_key_with_benchmark(data, plaintext_key)

        expect(encryption_info.statistics).not_to be_nil

        expect(encryption_info.statistics).to have_key(:encrypt)
      end
    end

    describe '#decrypt_with_key_with_benchmark' do
      it 'returns encryption statistics' do
        encryption_info = symmetric.encrypt_with_key_with_benchmark(data, plaintext_key)
        decryption_info = symmetric.decrypt_with_key_with_benchmark(encryption_info.ciphertext, plaintext_key, encryption_info.nonce)

        expect(decryption_info.statistics).not_to be_nil

        expect(decryption_info.statistics).to have_key(:decrypt)
      end
    end
  end
end
