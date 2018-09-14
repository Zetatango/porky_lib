# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::FileService, type: :request do
  let(:file_service) { described_class.instance }
  let(:default_config) do
    { aws_region: 'us-east-1',
      aws_key_id: 'abc',
      aws_key_secret: '123' }
  end
  let(:bucket_name) { 'porky_bucket' }
  let(:default_key_id) { 'alias/porky' }
  let(:plaintext_data) { 'abc123' }
  let(:ciphertext_data) do
    "{\"key\":\"G2JpGKOwMKOiHl1vKbsbIE54j5E2UUXvkavDtIX4PfogxMB5a3JvcC9zYWlsYauT\",
    \"data\":\"SQmWQavlGC7FJGsg3M0IovBR38W7SQ==\",
    \"nonce\":\"BXFEzR4U1u_muThKSOYdaOP9JHUhlKIZ\"}"
  end

  before do
    PorkyLib::Config.configure(default_config)
    PorkyLib::Config.initialize_aws
    Aws.config[:s3] = {
      stub_responses: {
        get_object: {
          body: ciphertext_data
        }
      }
    }
  end

  def write_test_file
    tempfile = Tempfile.new
    tempfile << plaintext_data
    tempfile.close
    tempfile
  end

  it 'write encrypted data to S3' do
    allow(Aws::S3::Object).to receive(:upload_file).and_return(true)
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id)
    expect(file_key).not_to be_nil
    allow(Aws::S3::Object).to receive(:upload_file).and_call_original
  end

  it 'write encrypted data to S3 with metadata' do
    allow(Aws::S3::Object).to receive(:upload_file).and_return(true)
    metadata = { content_type: 'test/data' }
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id, metadata: metadata)
    expect(file_key).not_to be_nil
    allow(Aws::S3::Object).to receive(:upload_file).and_call_original
  end

  it 'write file to S3' do
    allow(Aws::S3::Object).to receive(:upload_file).and_return(true)
    file_key = file_service.write(write_test_file.path, bucket_name, default_key_id)
    expect(file_key).not_to be_nil
    allow(Aws::S3::Object).to receive(:upload_file).and_call_original
  end

  it 'write file to S3 with metadata' do
    tempfile = write_test_file
    allow(Aws::S3::Object).to receive(:upload_file).and_return(true)
    metadata = { content_type: 'test/data' }
    file_key = file_service.write(tempfile.path, bucket_name, default_key_id, metadata: metadata)
    expect(file_key).not_to be_nil
    allow(Aws::S3::Object).to receive(:upload_file).and_call_original
  end

  it 'read encrypted data from S3' do
    allow(Aws::S3::Object).to receive(:upload_file).and_return(true)
    file_key = file_service.write(plaintext_data, bucket_name, default_key_id)

    allow(Aws::S3::Object).to receive(:download_file).and_return(ciphertext_data)
    plaintext = file_service.read(bucket_name, file_key)
    expect(plaintext_data).to eq(plaintext)

    allow(Aws::S3::Object).to receive(:upload_file).and_call_original
    allow(Aws::S3::Object).to receive(:download_file).and_call_original
  end
end
