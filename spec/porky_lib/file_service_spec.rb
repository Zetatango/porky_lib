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
  let(:ciphertext_data_large) { File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_ciphertext") }
  let(:plaintext_data_large) { File.read("spec#{File::SEPARATOR}porky_lib#{File::SEPARATOR}data#{File::SEPARATOR}large_plaintext") }

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

  def stub_large_file(large_file)
    Aws.config[:s3].delete(:stub_responses)

    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: large_file
        },
        head_object: {
          content_length: large_file.bytesize
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

  describe '#write' do
    it 'write encrypted data to S3' do
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id)
      expect(file_key).not_to be_nil
    end

    it 'write large encrypted data to S3' do
      file_key = file_service.write(plaintext_data_large,
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
        file_service.write(write_test_file(plaintext_data_large).path,
                           bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
    end

    it 'write file too large to S3' do
      file_key = file_service.write(write_test_file(plaintext_data_large).path,
                                    bucket_name, default_key_id)
      expect(file_key).not_to be_nil
    end

    it 'write file to S3 with metadata' do
      tempfile = write_test_file(plaintext_data)
      metadata = { content_type: 'test/data' }
      file_key = file_service.write(tempfile.path, bucket_name, default_key_id, metadata: metadata)
      expect(file_key).not_to be_nil
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
  end

  describe '#overwrite_file' do
    it 'overwrite encrypted data to S3' do
      expect do
        file_service.overwrite_file(plaintext_data, default_file_key, bucket_name, default_key_id)
      end.not_to raise_exception
    end

    it 'overwrite large encrypted data to S3' do
      expect do
        file_service.overwrite_file(plaintext_data_large, default_file_key,
                                    bucket_name, default_key_id)
      end.not_to raise_exception
    end

    it 'overwrite encrypted data to S3 with metadata' do
      expect do
        metadata = { content_type: 'test/data' }
        file_service.overwrite_file(plaintext_data, default_file_key, bucket_name, default_key_id, metadata: metadata)
      end.not_to raise_exception
    end

    it 'overwrite file too large to S3' do
      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.overwrite_file(plaintext_data_large, default_file_key,
                                    bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
    end

    it 'attempt to overwrite to bucket without permission raises FileServiceError' do
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

    it 'attempt to overwrite an existing file with nil file_key raise FileServiceError' do
      expect do
        file_service.overwrite_file(plaintext_data, nil, bucket_name, default_key_id)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end
  end

  describe '#read' do
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
      stub_large_file(ciphertext_data_large)
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

      plaintext, = file_service.read(bucket_name, file_key)
      expect(plaintext_data_large).to eq(plaintext)
    end

    it 'read encrypted data too large from S3' do
      stub_large_file(ciphertext_data_large)
      file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.read(bucket_name, file_key)
      end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
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

  describe '#read_raw_file' do
    before do
      Aws.config[:s3] = {
        stub_responses: {
          get_object: {
            body: plaintext_data
          }
        }
      }
    end
    it 'read un-encrypted data from S3' do
      file_key = write_test_file(plaintext_data).path

      plaintext = file_service.read_raw_file(bucket_name, file_key)
      expect(plaintext_data).to eq(plaintext)
    end

    it 'read large un-encrypted data from S3' do
      stub_large_file(plaintext_data_large)
      file_key = write_test_file(plaintext_data).path

      plaintext = file_service.read_raw_file(bucket_name, file_key)
      expect(plaintext_data_large).to eq(plaintext)
    end

    it 'read un-encrypted data too large from S3' do
      stub_large_file(plaintext_data_large)
      file_key = write_test_file(plaintext_data).path

      PorkyLib::Config.configure(max_file_size: 10 * 1024)
      expect do
        file_service.read_raw_file(bucket_name, file_key)
      end.to raise_exception(PorkyLib::FileService::FileSizeTooLargeError)
    end

    it 'attempt to read from bucket without permission raises FileServiceError' do
      Aws.config[:s3].delete(:stub_responses)
      Aws.config[:s3] = {
        stub_responses: {
          get_object: 'Forbidden'
        }
      }
      expect do
        file_service.read_raw_file(bucket_name, default_key_id)
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
        file_service.read_raw_file(bucket_name, default_key_id)
      end.to raise_exception(PorkyLib::FileService::FileServiceError)
    end
  end

  describe '#file_contents' do
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

  describe '#presigned_post' do
    let(:s3_bucket) { instance_double(Aws::S3::Bucket) }

    it 'returns presigned post url and fields' do
      url, fields = file_service.presigned_post(bucket_name, default_file_key)
      
      expect(url).to eq("https://s3.amazonaws.com/#{bucket_name}")
      expect(fields["key"]).to eq(default_file_key)
      expect(fields["policy"]).not_to be_nil
      expect(fields["x-amz-credential"]).not_to be_nil
      expect(fields["x-amz-algorithm"]).not_to be_nil
      expect(fields["x-amz-date"]).not_to be_nil
      expect(fields["x-amz-signature"]).not_to be_nil
    end

    it 'raises a FileServiceError on S3 lib exception' do
      allow(Aws::S3::Bucket).to receive(:new).and_return(s3_bucket)
      allow(s3_bucket).to receive(:presigned_post).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))

      expect do
        file_service.presigned_post(bucket_name, default_file_key)
      end.to raise_error(PorkyLib::FileService::FileServiceError)
    end

    it 'logs the error' do
      allow(Aws::S3::Bucket).to receive(:new).and_return(s3_bucket)
      allow(s3_bucket).to receive(:presigned_post).and_raise(Aws::S3::Errors::ServiceError.new(nil, 'Error'))
      begin
        file_service.presigned_post(bucket_name, default_file_key)
      rescue PorkyLib::FileService::FileServiceError => e
        expect(e.message).to match(/\APresignedPost for #{default_file_key} from S3 bucket #{bucket_name} failed:\s+/)
      end
    end
  end
end
