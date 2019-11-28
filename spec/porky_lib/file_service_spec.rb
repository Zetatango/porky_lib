# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::FileService, type: :request do
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
  let(:metadata) do
    {
      report_type: 'business report',
      report_date: Date.today.to_s,
      extra_metadata: 'extra metadata info'
    }
  end

  # ASCII_8BIT String with character, \xC3, has undefined conversion from ACSII-8BIT to UTF-8
  let(:binary_contents) { (+"\xC3Hello").force_encoding("ASCII-8BIT") }
  let(:null_byte_contents) { (+"\xA0\0").force_encoding("ASCII-8BIT") }

  before do
    PorkyLib::Config.configure(default_config)
    PorkyLib::Config.initialize_aws
    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: ciphertext_data
        },
        head_object: {
          content_length: ciphertext_data.bytesize,
          metadata: {
            "metadata1" => "value1",
            "metadata2" => "value2"
          }
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
    tempfile.flush
    tempfile
  end

  def test_file_content(expected_content, binary = false)
    allow(Aws::S3::Object).to receive(:new).and_return(aws_s3_object)
    allow(aws_s3_object).to receive(:upload_file)

    tempfile = Tempfile.new
    allow(Tempfile).to receive(:new).and_return(tempfile)
    allow(tempfile).to receive(:unlink)
    allow(tempfile).to receive(:close)

    file_key = yield

    expect(aws_s3_object).to have_received(:upload_file) do |_tempfile_path|
      tempfile.rewind

      message, = file_service.send(:decrypt_file_contents, tempfile)
      message = (+message).force_encoding('ASCII-8BIT') if binary

      expect(message).to eq(expected_content)
    end
    expect(file_key).not_to be_nil
  end

  describe '#write' do
    it 'raises FileServiceError when file is nil' do
      expect do
        file_service.write(nil, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket name is nil' do
      expect do
        file_service.write(plaintext_data, nil, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when key ID is nil ' do
      expect do
        file_service.write(plaintext_data, bucket_name, nil)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'writes the right content to S3 if file object is used' do
      file = write_test_file(plaintext_data)

      test_file_content(plaintext_data) do
        file_service.write(file, bucket_name, default_key_id)
      end
    end

    it 'writes the right content to S3 if path is used' do
      path = write_test_file(plaintext_data).path

      test_file_content(plaintext_data) do
        file_service.write(path, bucket_name, default_key_id)
      end
    end

    it 'writes the right image file content to S3 if path is used' do
      path = "spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}image.png"
      data = File.read(path, encoding: 'ASCII-8BIT')

      test_file_content(data, true) do
        file_service.write(path, bucket_name, default_key_id)
      end
    end

    it 'writes the right content to S3 if content is used' do
      test_file_content(plaintext_data) do
        file_service.write(plaintext_data, bucket_name, default_key_id)
      end
    end

    it 'handles contents containing a null byte when reading a file' do
      test_file_content(null_byte_contents, true) do
        file_service.write(null_byte_contents, bucket_name, default_key_id)
      end
    end

    it 'handles content encoded as ASCII_8BIT (BINARY) when creating the tempfile' do
      test_file_content(binary_contents, true) do
        file_service.write(binary_contents, bucket_name, default_key_id)
      end
    end
  end

  describe '#write_file' do
    it 'writes file to s3' do
      file_key = file_service.write_file(write_test_file(plaintext_data), bucket_name, default_key_id)
      expect(file_key).not_to be_nil
    end

    it 'writes the right content to S3 if file object is used' do
      file = write_test_file(plaintext_data)

      test_file_content(plaintext_data) do
        file_service.write_file(file, bucket_name, default_key_id)
      end
    end

    it 'writes the right content to S3 if path is used' do
      path = write_test_file(plaintext_data).path

      test_file_content(plaintext_data) do
        file_service.write_file(path, bucket_name, default_key_id)
      end
    end

    it 'raises FileServiceError when file path does not exist' do
      expect do
        file_service.write_file('non_existent_path', bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileServiceHelper::FileServiceError)
    end

    it 'raises FileServiceError when file cannot be read (no permission)' do
      path = write_test_file(plaintext_data).path

      expect do
        File.chmod(0o000, path)
        file_service.write_file(path, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileServiceHelper::FileServiceError)
    end

    it 'raises FileServiceError when file is nil ' do
      expect do
        file_service.write_file(nil, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket name is nil' do
      expect do
        file_service.write_file(write_test_file(plaintext_data), nil, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when key ID is nil ' do
      expect do
        file_service.write_file(write_test_file(plaintext_data), bucket_name, nil)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end
  end

  describe '#write_data' do
    it 'writes encrypted data to S3' do
      file_key = file_service.write_data(plaintext_data, bucket_name, default_key_id)
      expect(file_key).not_to be_nil
    end

    it 'writes large encrypted data to S3' do
      file_key = file_service.write_data(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext"),
                                         bucket_name, default_key_id)
      expect(file_key).not_to be_nil
    end

    it 'writes encrypted data to S3 with metadata' do
      metadata = { content_type: 'test/data' }
      file_key = file_service.write_data(plaintext_data, bucket_name, default_key_id, metadata: metadata)
      expect(file_key).not_to be_nil
    end

    it 'writes plaintext data to S3 with a different storage_class' do
      storage_class = 'REDUCED_REDUNDANCY'
      file_key = file_service.write_data(plaintext_data, bucket_name, storage_class: storage_class)
      expect(file_key).not_to be_nil
    end

    it 'writes encrypted data to S3 with a custom file name' do
      custom_file_name = 'custom_file_name'
      file_key = file_service.write_data(plaintext_data, bucket_name, default_key_id, file_name: custom_file_name)
      expect(file_key).to eq(custom_file_name)
    end

    it 'writes encrypted data to S3 with directory' do
      file_key = file_service.write_data(plaintext_data, bucket_name, default_key_id, directory: '/directory1/dirA')
      expect(file_key).not_to be_nil
    end

    it 'writes the right content to S3 if content is used' do
      test_file_content(plaintext_data) do
        file_service.write_data(plaintext_data, bucket_name, default_key_id)
      end
    end

    it 'writes the right image file content to S3 if content is used' do
      data = File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}image.png", encoding: 'ASCII-8BIT')

      test_file_content(data, true) do
        file_service.write_data(data, bucket_name, default_key_id)
      end
    end

    it 'raises FileSizeTooLargeError when data is bigger than max_file_size' do
      allow(PorkyLib::Config).to receive(:config).and_return(PorkyLib::Config.config.merge(max_file_size: 1))

      expect do
        file_service.write_data(plaintext_data, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
    end

    it 'raises FileServiceError when data is nil ' do
      expect do
        file_service.write_data(nil, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket name is nil ' do
      expect do
        file_service.write_data(plaintext_data, nil, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when key ID is nil ' do
      expect do
        file_service.write_data(plaintext_data, bucket_name, nil)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when writing to bucket without permission ' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          put_object: 'Forbidden'
        }
      }
      expect do
        file_service.write_data(plaintext_data, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when writing to bucket that does not exist ' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          put_object: 'NotFound'
        }
      }
      expect do
        file_service.write_data(plaintext_data, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'handles contents containing a null byte when reading a file' do
      test_file_content(null_byte_contents, true) do
        file_service.write_data(null_byte_contents, bucket_name, default_key_id)
      end
    end

    it 'handles content encoded as ASCII_8BIT (BINARY) when creating the tempfile' do
      test_file_content(binary_contents, true) do
        file_service.write_data(binary_contents, bucket_name, default_key_id)
      end
    end
  end

  describe '#overwrite' do
    it 'overwrites encrypted data to S3' do
      expect do
        file_service.overwrite_file(plaintext_data, default_file_key, bucket_name, default_key_id)
      end.not_to raise_exception
    end

    it 'overwrites large encrypted data to S3' do
      expect do
        file_service.overwrite_file(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext"), default_file_key,
                                    bucket_name, default_key_id)
      end.not_to raise_exception
    end

    it 'overwrites encrypted data to S3 with metadata' do
      expect do
        metadata = { content_type: 'test/data' }
        file_service.overwrite_file(plaintext_data, default_file_key, bucket_name, default_key_id, metadata: metadata)
      end.not_to raise_exception
    end

    it 'overwrites encrypted data too large to S3' do
      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.overwrite_file(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext"), default_file_key,
                                    bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
    end

    it 'raises FileServiceError when overwriting file to bucket without permission' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          put_object: 'Forbidden'
        }
      }
      expect do
        file_service.overwrite_file(plaintext_data, default_file_key, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when file is nil' do
      expect do
        file_service.overwrite_file(nil, default_file_key, bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when overwriting an existing file with nil file_key ' do
      expect do
        file_service.overwrite_file(plaintext_data, nil, bucket_name, default_key_id)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when bucket name is nil' do
      expect do
        file_service.overwrite_file(plaintext_data, default_file_key, nil, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end

    it 'raises FileServiceError when key ID is nil ' do
      expect do
        file_service.overwrite_file(plaintext_data, default_file_key, bucket_name, nil)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end
  end

  describe '#read' do
    it 'reads encrypted data from S3' do
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

      plaintext, should_reencrypt = file_service.read(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
      expect(should_reencrypt).to be_falsey
    end

    it 'reads encrypted data from S3 with directory' do
      dir_name = 'directory1/dirA'
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id, directory: dir_name)
      expect(file_key).to include(dir_name)

      plaintext, should_reencrypt = file_service.read(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
      expect(should_reencrypt).to be_falsey
    end

    it 'reads encrypted data from S3 which should be re-encrypted' do
      stub_data_to_be_reencrypted
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

      plaintext, should_reencrypt = file_service.read(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
      expect(should_reencrypt).to be_truthy
    end

    it 'reads large encrypted data from S3' do
      stub_large_file
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

      plaintext, = file_service.read(bucket_name, file_key)
      expect(File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext")).to eq(plaintext)
    end

    it 'reads encrypted data too large from S3' do
      stub_large_file
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.read(bucket_name, file_key)
      end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
    end

    it 'raises FileServiceError if reading from bucket without permission ' do
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

    it 'raises FileServiceError when bucket does not exist ' do
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

  it 'file_contents contains associated metadata if provided' do
    file_data = JSON.parse(ciphertext_data, symbolize_names: true)
    file_contents = file_service.send(:file_contents, file_data[:key], file_data[:data], file_data[:nonce], metadata: metadata)
    expect(JSON.parse(file_contents, symbolize_names: true)[:metadata]).to eq(metadata)
  end

  it 'file_contents does not contain metadata field if none provided' do
    file_data = JSON.parse(ciphertext_data, symbolize_names: true)
    file_contents = file_service.send(:file_contents, file_data[:key], file_data[:data], file_data[:nonce], {})
    expect(JSON.parse(file_contents, symbolize_names: true)).not_to have_key(:metadata)
  end

  it 'file_contents does not contain metadata field if options is nil' do
    file_data = JSON.parse(ciphertext_data, symbolize_names: true)
    file_contents = file_service.send(:file_contents, file_data[:key], file_data[:data], file_data[:nonce], nil)
    expect(JSON.parse(file_contents, symbolize_names: true)).not_to have_key(:metadata)
  end

  describe '#read_file_info' do
    let(:s3_service) { instance_double(Aws::S3::Client) }

    it 'raises a FileServiceError on S3 lib exception' do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_service)
      allow(s3_service).to receive(:head_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      expect do
        file_service.read_file_info(bucket_name, default_file_key)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end

    it 'logs the error' do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_service)
      allow(s3_service).to receive(:head_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      begin
        file_service.read_file_info(bucket_name, default_file_key)
      rescue PorkyLib::FileService::FileServiceError => e
        expect(e.message).to match(/\AFile info read for #{default_file_key} in S3 bucket #{bucket_name} failed:\s+/)
      end
    end

    it 'returns file metadata' do
      file_info = file_service.read_file_info(bucket_name, default_file_key)
      expect(file_info).to have_key(:metadata)
      expect(file_info[:metadata]).to have_key('metadata1')
      expect(file_info[:metadata]).to have_key('metadata2')
    end
  end

  describe '#copy_file' do
    let(:s3_service) { instance_double(Aws::S3::Client) }

    it 'raises a FileServiceError on S3 lib exception' do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_service)
      allow(s3_service).to receive(:copy_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      expect do
        file_service.copy_file(source_bucket, destination_bucket, default_file_key)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end

    it 'logs the error' do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_service)
      allow(s3_service).to receive(:copy_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      begin
        file_service.copy_file(source_bucket, destination_bucket, default_file_key)
      rescue PorkyLib::FileService::FileServiceError => e
        expect(e.message).to match(/\AFile move #{default_file_key} from S3 bucket #{source_bucket} to #{destination_bucket} failed:\s+/)
      end
    end

    it 'returns the file key' do
      file_key = file_service.copy_file(source_bucket, destination_bucket, default_file_key)
      expect(file_key).to eq(default_file_key)
    end
  end

  describe '#delete_file' do
    let(:s3_service) { instance_double(Aws::S3::Client) }

    it 'raises a FileServiceError on S3 lib exception' do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_service)
      allow(s3_service).to receive(:delete_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      expect do
        file_service.delete_file(bucket_name, default_file_key)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end

    it 'logs the error' do
      allow(Aws::S3::Client).to receive(:new).and_return(s3_service)
      allow(s3_service).to receive(:delete_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      begin
        file_service.delete_file(bucket_name, default_file_key)
      rescue PorkyLib::FileService::FileServiceError => e
        expect(e.message).to match(/\AFile delete of #{default_file_key} from S3 bucket #{bucket_name} failed:\s+/)
      end
    end

    it 'does not raise an exception on success' do
      expect do
        file_service.delete_file(bucket_name, default_file_key)
      end.not_to raise_error
    end
  end

  describe '#presigned_post_url' do
    let(:s3_object) { instance_double(Aws::S3::Object) }

    it 'returns presigned post url' do
      url, _file_name = file_service.presigned_post_url(bucket_name)
      uri = URI.parse(url)

      expect(uri.scheme).to eq('https')
      expect(uri.path).to include("/#{bucket_name}/")
    end

    it 'uses file_name as key if provided' do
      url, file_name = file_service.presigned_post_url(bucket_name, file_name: default_file_key)
      uri = URI.parse(url)

      expect(uri.path).to eq("/#{bucket_name}/#{default_file_key}")
      expect(default_file_key).to eq(file_name)
    end

    it 'passes metadata if provided' do
      url, _file_name = file_service.presigned_post_url(bucket_name, metadata: metadata)
      uri = URI.parse(url)
      query_params = CGI.parse(uri.query)

      expect(uri.scheme).to eq('https')
      expect(query_params["x-amz-meta-report_type"]).to eq([metadata[:report_type]])
      expect(query_params["x-amz-meta-report_date"]).to eq([metadata[:report_date]])
      expect(query_params["x-amz-meta-extra_metadata"]).to eq([metadata[:extra_metadata]])
    end

    it 'sets expiry date based on value defined in config' do
      url, _file_name = file_service.presigned_post_url(bucket_name)
      uri = URI.parse(url)
      query_params = CGI.parse(uri.query)

      expect(query_params["X-Amz-Expires"]).to eq([PorkyLib::Config.config[:presign_url_expires_in].to_s])
    end

    it 'raises a FileServiceError on S3 lib exception' do
      allow(Aws::S3::Object).to receive(:new).and_return(s3_object)
      allow(s3_object).to receive(:presigned_url).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))

      expect do
        file_service.presigned_post_url(bucket_name)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end

    it 'logs the error' do
      allow(Aws::S3::Object).to receive(:new).and_return(s3_object)
      allow(s3_object).to receive(:presigned_url).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      begin
        file_service.presigned_post_url(bucket_name, file_name: default_file_key)
      rescue PorkyLib::FileService::FileServiceError => e
        expect(e.message).to match(/\APresignedPostUrl for #{default_file_key} from S3 bucket #{bucket_name} failed:\s+/)
      end
    end
  end

  describe '#presigned_get_url' do
    let(:s3_object) { instance_double(Aws::S3::Object) }

    it 'returns presigned get url and fields' do
      url = file_service.presigned_get_url(bucket_name, default_file_key)
      uri = URI.parse(url)

      expect(uri.scheme).to eq('https')
      expect(uri.path).to eq("/#{bucket_name}/#{default_file_key}")
    end

    it 'sets expiry date based on value defined in config' do
      url = file_service.presigned_get_url(bucket_name, default_file_key)
      uri = URI.parse(url)
      query_params = CGI.parse(uri.query)

      expect(query_params["X-Amz-Expires"]).to eq([PorkyLib::Config.config[:presign_url_expires_in].to_s])
    end

    it 'raises a FileServiceError on S3 lib exception' do
      allow(Aws::S3::Object).to receive(:new).and_return(s3_object)
      allow(s3_object).to receive(:presigned_url).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))

      expect do
        file_service.presigned_get_url(bucket_name, default_file_key)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end

    it 'logs the error' do
      allow(Aws::S3::Object).to receive(:new).and_return(s3_object)
      allow(s3_object).to receive(:presigned_url).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      begin
        file_service.presigned_get_url(bucket_name, default_file_key)
      rescue PorkyLib::FileService::FileServiceError => e
        expect(e.message).to match(/\APresignedGetUrl for #{default_file_key} from S3 bucket #{bucket_name} failed:\s+/)
      end
    end
  end
end
