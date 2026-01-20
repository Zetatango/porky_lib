# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::Unencrypted::FileService, type: :request do
  let(:file_service) { described_class.clone.instance }
  let(:aws_s3_object) { instance_double(Aws::S3::Object) }
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

  # ASCII_8BIT String with character, \xC3, has undefined conversion from ACSII-8BIT to UTF-8
  let(:binary_contents) { (+"\xC3Hello").force_encoding("ASCII-8BIT") }
  let(:null_byte_contents) { (+"\xA0\0").force_encoding("ASCII-8BIT") }

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

  def test_file_content(expected_content, binary: false)
    aws_s3_client = instance_double(Aws::S3::Client)
    allow(Aws::S3::Client).to receive(:new).and_return(aws_s3_client)
    allow(aws_s3_client).to receive(:put_object)

    file_key = yield

    expect(file_key).not_to be_nil
    expect(aws_s3_client).to have_received(:put_object) do |options|
      data = options[:body].read
      data = (+data).force_encoding("ASCII-8BIT") if binary
      expect(data).to eq(expected_content)
    end
  end

  # rubocop:disable RSpec/NoExpectationExample
  describe '#write' do
    it 'raises FileServiceError when file is nil' do
      expect do
        file_service.write(nil, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket name is nil' do
      expect do
        file_service.write(plaintext_data, nil)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'writes the right content to S3 if file object is used' do
      file = write_test_file(plaintext_data)

      test_file_content(plaintext_data) do
        file_service.write(file, bucket_name)
      end
    end

    it 'writes the right content to S3 if path is used' do
      path = write_test_file(plaintext_data).path

      test_file_content(plaintext_data) do
        file_service.write(path, bucket_name)
      end
    end

    it 'writes the right image file content to S3 if path is used' do
      path = "spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}image.png"
      data = File.read(path, encoding: 'ASCII-8BIT')

      test_file_content(data, binary: true) do
        file_service.write(path, bucket_name)
      end
    end

    it 'writes the right content to S3 if content is used' do
      test_file_content(plaintext_data) do
        file_service.write(plaintext_data, bucket_name)
      end
    end

    it 'handles contents containing a null byte when reading a file and writes the right content' do
      test_file_content(null_byte_contents, binary: true) do
        file_service.write(null_byte_contents, bucket_name)
      end
    end

    it 'handles content encoded as ASCII_8BIT (BINARY) when creating the tempfile and writes the right content' do
      test_file_content(binary_contents, binary: true) do
        file_service.write(binary_contents, bucket_name)
      end
    end
  end

  describe '#write_file' do
    it 'writes file to s3' do
      file_key = file_service.write_file(write_test_file(plaintext_data), bucket_name)
      expect(file_key).not_to be_nil
    end

    it 'writes the right content to S3 if file object is used' do
      file = write_test_file(plaintext_data)

      test_file_content(plaintext_data) do
        file_service.write_file(file, bucket_name)
      end
    end

    it 'writes the right content to S3 if path is used' do
      path = write_test_file(plaintext_data).path

      test_file_content(plaintext_data) do
        file_service.write_file(path, bucket_name)
      end
    end

    it 'raises FileServiceError when file path does not exist' do
      expect do
        file_service.write_file('non_existent_path', bucket_name)
      end.to raise_exception(PorkyLib::FileServiceHelper::FileServiceError)
    end

    it 'raises FileServiceError when file cannot be read (no permission)' do
      path = write_test_file(plaintext_data).path

      expect do
        File.chmod(0o000, path)
        file_service.write_file(path, bucket_name)
      end.to raise_exception(PorkyLib::FileServiceHelper::FileServiceError)
    end

    it 'raises FileServiceError when file is nil' do
      expect do
        file_service.write_file(nil, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket name is nil' do
      expect do
        file_service.write_file(write_test_file(plaintext_data), nil)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end
  end

  describe '#write_data' do
    it 'writes plaintext data to S3' do
      file_key = file_service.write_data(plaintext_data, bucket_name)
      expect(file_key).not_to be_nil
    end

    it 'writes large plaintext data to S3' do
      file_key = file_service.write_data(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext"),
                                         bucket_name)
      expect(file_key).not_to be_nil
    end

    it 'writes plaintext data to S3 with metadata' do
      metadata = { content_type: 'test/data' }
      file_key = file_service.write_data(plaintext_data, bucket_name, metadata:)
      expect(file_key).not_to be_nil
    end

    it 'writes plaintext data to S3 with a different storage_class' do
      storage_class = 'REDUCED_REDUNDANCY'
      file_key = file_service.write_data(plaintext_data, bucket_name, storage_class:)
      expect(file_key).not_to be_nil
    end

    it 'writes encrypted data to S3 with a custom file name' do
      custom_file_name = 'custom_file_name'
      file_key = file_service.write_data(plaintext_data, bucket_name, file_name: custom_file_name)
      expect(file_key).to eq(custom_file_name)
    end

    it 'writes plaintext data to S3 with directory' do
      file_key = file_service.write_data(plaintext_data, bucket_name, directory: '/directory1/dirA')
      expect(file_key).not_to be_nil
    end

    it 'writes the right content to S3 if content is used' do
      test_file_content(plaintext_data) do
        file_service.write_data(plaintext_data, bucket_name)
      end
    end

    it 'writes the right image file content to S3 if content is used' do
      data = File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}image.png", encoding: 'ASCII-8BIT')

      test_file_content(data, binary: true) do
        file_service.write_data(data, bucket_name)
      end
    end

    it 'raises FileSizeTooLargeError when data is bigger than max_file_size' do
      allow(PorkyLib::Config).to receive(:config).and_return(PorkyLib::Config.config.merge(max_file_size: 1))

      expect do
        file_service.write_data(plaintext_data, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileSizeTooLargeError)
    end

    it 'raises FileServiceError when data is nil' do
      expect do
        file_service.write_data(nil, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket name is nil' do
      expect do
        file_service.write_data(plaintext_data, nil)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'raises FileServiceError when writing to bucket without permission' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          put_object: 'Forbidden'
        }
      }
      expect do
        file_service.write_data(plaintext_data, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket does not exist' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          put_object: 'NotFound'
        }
      }
      expect do
        file_service.write_data(plaintext_data, bucket_name)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileServiceError)
    end

    it 'handles contents containing a null byte when reading a file and writes the right content' do
      test_file_content(null_byte_contents, binary: true) do
        file_service.write_data(null_byte_contents, bucket_name)
      end
    end

    it 'handles content encoded as ASCII_8BIT (BINARY) when creating the tempfile and writes the right content' do
      test_file_content(binary_contents, binary: true) do
        file_service.write_data(binary_contents, bucket_name)
      end
    end
  end

  describe '#read' do
    it 'reads plaintext data from S3' do
      file_key = file_service.write(plaintext_data, bucket_name)

      plaintext = file_service.read(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
    end

    it 'reads plaintext data from S3 with directory' do
      dir_name = 'directory1/dirA'
      file_key = file_service.write(plaintext_data, bucket_name, directory: dir_name)
      expect(file_key).to include(dir_name)

      plaintext = file_service.read(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
    end

    it 'reads large plaintext data from S3' do
      stub_large_file
      file_key = file_service.write(plaintext_data, bucket_name)

      plaintext, = file_service.read(bucket_name, file_key)
      expect(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")).to eq(plaintext)
    end

    it 'reads plaintext data too large from S3' do
      stub_large_file
      file_key = file_service.write(plaintext_data, bucket_name)

      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.read(bucket_name, file_key)
      end.to raise_exception(PorkyLib::Unencrypted::FileService::FileSizeTooLargeError)
    end

    it 'raises FileServiceError when reading bucket without permission' do
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

    it 'raises FileServiceError when bucket does not exist' do
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
  # rubocop:enable RSpec/NoExpectationExample
end
