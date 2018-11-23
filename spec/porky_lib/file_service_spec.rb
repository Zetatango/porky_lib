# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::FileService, type: :request do
  let(:file_service) { described_class.clone.instance }
  let(:default_config) do
    { aws_region: 'us-east-1',
      aws_key_id: 'abc',
      aws_key_secret: '123',
      max_file_size: 10 * 1024 * 1024 }
  end
  let(:bucket_name) { 'porky_bucket' }
  let(:default_key_id) { 'alias/porky' }
  let(:plaintext_data) { 'abc123' }
  let(:ciphertext_data) do
    {
      key: 'KrUyzr7rL4lYjuFqmeqzDGqG7Kktz6SeBCqiVbLXtWsgxMB5a3JvcC9zYWlsYauT',
      data: 'Heqj1FnHmZqnKpws-_GgX1t_FgdCZA==',
      nonce: 'XL09bELoWZ_7rzev9gSkFhBYsFdGETdL'
    }.to_json
  end
  let(:ciphertext_data_reencrypt) do
    {
      key: 'G2JpGKOwMKOiHl1vKbsbIE54j5E2UUXvkavDtIX4PfogxMB5a3JvcC9zYWlsYauT',
      data: 'SQmWQavlGC7FJGsg3M0IovBR38W7SQ==',
      nonce: 'BXFEzR4U1u_muThKSOYdaOP9JHUhlKIZ'
    }.to_json
  end

  before do
    PorkyLib::Config.configure(default_config)
    PorkyLib::Config.initialize_aws
    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: ciphertext_data
        },
        head_object: {
          content_length: ciphertext_data.bytesize
        }
      }
    }
  end

  def stub_data_to_be_reencrypted
    Aws.config[:s3].delete(:stub_responses)
    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: ciphertext_data_reencrypt
        },
        head_object: {
          content_length: ciphertext_data_reencrypt.bytesize
        }
      }
    }
  end

  def stub_large_file
    Aws.config[:s3].delete(:stub_responses)

    ciphertext_data_large = File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_ciphertext")
    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: ciphertext_data_large
        },
        head_object: {
          content_length: ciphertext_data_large.bytesize
        }
      }
    }
  end

  def write_test_file(data)
    tempfile = Tempfile.new
    tempfile << data
    tempfile.close
    tempfile
  end

  it 'write encrypted data to S3' do
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id)
    expect(file_key).not_to be_nil
  end

  it 'write large encrypted data to S3' do
    file_key = file_service.write(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext"),
                                  bucket_name, default_key_id)
    expect(file_key).not_to be_nil
  end

  it 'write encrypted data to S3 with metadata' do
    metadata = { content_type: 'test/data' }
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id, metadata: metadata)
    expect(file_key).not_to be_nil
  end

  it 'write encrypted data to S3 with directory' do
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id, directory: '/directory1/dirA')
    expect(file_key).not_to be_nil
  end

  it 'write file to S3' do
    file_key = file_service.write(write_test_file(plaintext_data).path, bucket_name, default_key_id)
    expect(file_key).not_to be_nil
  end

  it 'write large file to S3' do
    PorkyLib::Config.configure(max_file_size: 10 * 1024)
    expect do
      file_service.write(write_test_file(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")).path,
                         bucket_name, default_key_id)
    end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
  end

  it 'write file too large to S3' do
    file_key = file_service.write(write_test_file(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")).path,
                                  bucket_name, default_key_id)
    expect(file_key).not_to be_nil
  end

  it 'write file to S3 with metadata' do
    tempfile = write_test_file(plaintext_data)
    metadata = { content_type: 'test/data' }
    file_key = file_service.write(tempfile.path, bucket_name, default_key_id, metadata: metadata)
    expect(file_key).not_to be_nil
  end

  it 'read encrypted data from S3' do
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

    plaintext, should_reencrypt = file_service.read(bucket_name, file_key)
    expect(plaintext_data).to eq(plaintext)
    expect(should_reencrypt).to be_falsey
  end

  it 'read encrypted data from S3 with directory' do
    dir_name = 'directory1/dirA'
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id, directory: dir_name)
    expect(file_key).to include(dir_name)

    plaintext, should_reencrypt = file_service.read(bucket_name, file_key)
    expect(plaintext_data).to eq(plaintext)
    expect(should_reencrypt).to be_falsey
  end

  it 'read encrypted data from S3 which should be re-encrypted' do
    stub_data_to_be_reencrypted
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

    plaintext, should_reencrypt = file_service.read(bucket_name, file_key)
    expect(plaintext_data).to eq(plaintext)
    expect(should_reencrypt).to be_truthy
  end

  it 'read large encrypted data from S3' do
    stub_large_file
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

    plaintext, = file_service.read(bucket_name, file_key)
    expect(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")).to eq(plaintext)
  end

  it 'read encrypted data too large from S3' do
    stub_large_file
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

    PorkyLib::Config.configure(max_file_size: 10 * 1024)
    expect do
      file_service.read(bucket_name, file_key)
    end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
  end

  it 'attempt to write with file nil raises FileServiceError' do
    expect do
      file_service.write(nil, bucket_name, default_key_id)
    end.to raise_exception(PorkyLib::FileService::FileServiceError)
  end

  it 'attempt to write with bucket name nil raises FileServiceError' do
    expect do
      file_service.write(plaintext_data, nil, default_key_id)
    end.to raise_exception(PorkyLib::FileService::FileServiceError)
  end

  it 'attempt to write with key ID nil raises FileServiceError' do
    expect do
      file_service.write(plaintext_data, bucket_name, nil)
    end.to raise_exception(PorkyLib::FileService::FileServiceError)
  end

  it 'attempt to write to bucket without permission raises FileServiceError' do
    Aws.config[:s3].delete(:stub_responses)
    Aws.config[:s3] = {
      stub_responses: {
        put_object: 'Forbidden'
      }
    }
    expect do
      file_service.write(plaintext_data, bucket_name, default_key_id)
    end.to raise_exception(PorkyLib::FileService::FileServiceError)
  end

  it 'attempt to write to bucket that does not exist raises FileServiceError' do
    Aws.config[:s3].delete(:stub_responses)
    Aws.config[:s3] = {
      stub_responses: {
        put_object: 'NotFound'
      }
    }
    expect do
      file_service.write(plaintext_data, bucket_name, default_key_id)
    end.to raise_exception(PorkyLib::FileService::FileServiceError)
  end

  it 'attempt to read from bucket without permission raises FileServiceError' do
    Aws.config[:s3].delete(:stub_responses)
    Aws.config[:s3] = {
      stub_responses: {
        get_object: 'Forbidden'
      }
    }
    expect do
      file_service.read(bucket_name, default_key_id)
    end.to raise_exception(PorkyLib::FileService::FileServiceError)
  end

  it 'attempt to read from bucket does not exist raises FileServiceError' do
    Aws.config[:s3].delete(:stub_responses)
    Aws.config[:s3] = {
      stub_responses: {
        get_object: 'NotFound'
      }
    }
    expect do
      file_service.read(bucket_name, default_key_id)
    end.to raise_exception(PorkyLib::FileService::FileServiceError)
  end
end
