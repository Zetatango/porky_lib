# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::Unencrypted::FileService, type: :request do
  let(:file_service) { described_class.clone.instance }
  let(:default_config) do
    { aws_region: 'us-east-1',
      aws_key_id: 'abc',
      aws_key_secret: '123',
      max_file_size: 10 * 1024 * 1024 }
  end
  let(:bucket_name) { 'porky_bucket' }
  let(:source_bucket) { 'source' }
  let(:destination_bucket) { 'destination' }
  let(:default_key_id) { 'alias/porky' }
  let(:default_file_key) { 'file_key' }
  let(:plaintext_data) { 'abc123' }

  before do
    PorkyLib::Config.configure(default_config)
    PorkyLib::Config.initialize_aws
    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: plaintext_data
        },
        head_object: {
          content_length: plaintext_data.bytesize,
          metadata: {
            "metadata1" => "value1",
            "metadata2" => "value2"
          }
        }
      }
    }
  end

  def stub_large_file
    Aws.config[:s3].delete(:stub_responses)

    plaintext_data_large = File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")
    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: plaintext_data_large
        },
        head_object: {
          content_length: plaintext_data_large.bytesize
        }
      }
    }
  end

  def write_test_file(data)
    tempfile = Tempfile.new
    tempfile << data
    tempfile.flush
    tempfile
  end

  describe '#write' do
    it 'write plaintext data to S3' do
      file_key = file_service.write(plaintext_data, bucket_name)
      expect(file_key).not_to be_nil
    end

    it 'write large plaintext data to S3' do
      file_key = file_service.write(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext"),
                                    bucket_name)
      expect(file_key).not_to be_nil
    end

    it 'write plaintext data to S3 with metadata' do
      metadata = { content_type: 'test/data' }
      file_key = file_service.write(plaintext_data, bucket_name, metadata: metadata)
      expect(file_key).not_to be_nil
    end

    it 'write plaintext data to S3 with directory' do
      file_key = file_service.write(plaintext_data, bucket_name, directory: '/directory1/dirA')
      expect(file_key).not_to be_nil
    end

    it 'write file to S3' do
      file_key = file_service.write(write_test_file(plaintext_data), bucket_name)
      expect(file_key).not_to be_nil
    end

    it 'write large file to S3' do
      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.write(write_test_file(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")),
                           bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileSizeTooLargeError)
    end

    it 'write file too large to S3' do
      file_key = file_service.write(write_test_file(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")),
                                    bucket_name)
      expect(file_key).not_to be_nil
    end

    it 'write file to S3 with metadata' do
      tempfile = write_test_file(plaintext_data)
      metadata = { content_type: 'test/data' }
      file_key = file_service.write(tempfile, bucket_name, metadata: metadata)
      expect(file_key).not_to be_nil
    end

    it 'attempt to write with file nil raises FileServiceError' do
      expect do
        file_service.write(nil, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'attempt to write with bucket name nil raises FileServiceError' do
      expect do
        file_service.write(plaintext_data, nil)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'attempt to write to bucket without permission raises FileServiceError' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          put_object: 'Forbidden'
        }
      }
      expect do
        file_service.write(plaintext_data, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'attempt to write to bucket that does not exist raises FileServiceError' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          put_object: 'NotFound'
        }
      }
      expect do
        file_service.write(plaintext_data, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end
  end

  describe '#read' do
    it 'read plaintext data from S3' do
      file_key = file_service.write(plaintext_data, bucket_name)

      plaintext = file_service.read(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
    end

    it 'read plaintext data from S3 with directory' do
      dir_name = 'directory1/dirA'
      file_key = file_service.write(plaintext_data, bucket_name, directory: dir_name)
      expect(file_key).to include(dir_name)

      plaintext = file_service.read(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
    end

    it 'read large plaintext data from S3' do
      stub_large_file
      file_key = file_service.write(plaintext_data, bucket_name)

      plaintext, = file_service.read(bucket_name, file_key)
      expect(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")).to eq(plaintext)
    end

    it 'read plaintext data too large from S3' do
      stub_large_file
      file_key = file_service.write(plaintext_data, bucket_name)

      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.read(bucket_name, file_key)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileSizeTooLargeError)
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
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
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
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end
  end

  it 'file_size_invalid? handles contents containing a null byte when reading a file' do
    null_byte_contents = "\xA0\0"
    file_key = file_service.write(null_byte_contents, bucket_name)
    expect(file_key).not_to be_nil
  end

  it 'file_size_invalid? handles content encoded as ASCII_8BIT (BINARY) when creating the tempfile' do
    # ASCII_8BIT String with character, \xC3, has undefined conversion from ACSII-8BIT to UTF-8
    my_file_contents = "\xC3Hello"
    file_key = file_service.write(my_file_contents, bucket_name)
    expect(file_key).not_to be_nil
  end
end
