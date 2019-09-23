# frozen_string_literal: true

require 'singleton'
require 'porky_lib/file_service_helper'

class PorkyLib::FileService
  include Singleton
  include FileServiceHelper

  class FileServiceError < StandardError; end
  class FileSizeTooLargeError < StandardError; end

  def read_file_info(bucket_name, file_key)
    s3_client.head_object(
      bucket: bucket_name,
      key: file_key
    ).to_h
  rescue Aws::Errors::ServiceError => e
    raise FileServiceError, "File info read for #{file_key} in S3 bucket #{bucket_name} failed: #{e.message}"
  end

  def copy_file(source_bucket, destination_bucket, file_key)
    s3_client.copy_object(
      bucket: destination_bucket,
      copy_source: "#{source_bucket}/#{file_key}",
      key: file_key
    )

    file_key
  rescue Aws::Errors::ServiceError => e
    raise FileServiceError, "File move #{file_key} from S3 bucket #{source_bucket} to #{destination_bucket} failed: #{e.message}"
  end

  def delete_file(bucket_name, file_key)
    s3_client.delete_object(
      bucket: bucket_name,
      key: file_key
    )
  rescue Aws::Errors::ServiceError => e
    raise FileServiceError, "File delete of #{file_key} from S3 bucket #{bucket_name} failed: #{e.message}"
  end

  def read(bucket_name, file_key, options = {})
    tempfile = Tempfile.new

    begin
      object = s3.bucket(bucket_name).object(file_key)
      raise FileSizeTooLargeError, "File size is larger than maximum allowed size of #{max_file_size}" if object.content_length > max_size

      object.download_file(tempfile.path, options)
    rescue Aws::Errors::ServiceError => e
      raise FileServiceError, "Attempt to download a file from S3 failed.\n#{e.message}"
    end

    decrypt_file_contents(tempfile)
  end

  def write(file, bucket_name, key_id, options = {})
    raise FileServiceError, 'Invalid input. One or more input values is nil' if input_invalid?(file, bucket_name, key_id)
    raise FileSizeTooLargeError, "File size is larger than maximum allowed size of #{max_file_size}" if file_size_invalid?(file)

    data = file_data(file)
    file_key = options.key?(:directory) ? "#{options[:directory]}/#{SecureRandom.uuid}" : SecureRandom.uuid

    tempfile = encrypt_file_contents(data, key_id, file_key, options)

    begin
      perform_upload(bucket_name, file_key, tempfile, options)
    rescue Aws::Errors::ServiceError => e
      raise FileServiceError, "Attempt to upload a file to S3 failed.\n#{e.message}"
    end

    # Remove tempfile from disk
    tempfile.unlink
    file_key
  end

  def overwrite_file(file, file_key, bucket_name, key_id, options = {})
    raise FileServiceError, 'Invalid input. One or more input values is nil' if input_invalid?(file, bucket_name, key_id)
    raise FileServiceError, 'Invalid input. file_key cannot be nil if overwriting an existing file' if file_key.nil?
    raise FileSizeTooLargeError, "File size is larger than maximum allowed size of #{max_file_size}" if file_size_invalid?(file)

    data = file_data(file)
    tempfile = encrypt_file_contents(data, key_id, file_key, options)

    begin
      perform_upload(bucket_name, file_key, tempfile, options)
    rescue Aws::Errors::ServiceError => e
      raise FileServiceError, "Attempt to upload a file to S3 failed.\n#{e.message}"
    end

    # Remove tempfile from disk
    tempfile.unlink
  end

  def presigned_post_url(bucket_name, options = {})
    file_name = options[:file_name] || SecureRandom.uuid
    obj = s3.bucket(bucket_name).object(file_name)

    presigned_url = obj.presigned_url(:put,
                                      expires_in: presign_url_expires_in,
                                      metadata: options[:metadata])
    [presigned_url, file_name]
  rescue Aws::Errors::ServiceError => e
    raise FileServiceError, "PresignedPostUrl for #{file_name} from S3 bucket #{bucket_name} failed: #{e.message}"
  end

  def presigned_get_url(bucket_name, file_key)
    obj = s3.bucket(bucket_name).object(file_key)

    obj.presigned_url(:get,
                      expires_in: presign_url_expires_in)
  rescue Aws::Errors::ServiceError => e
    raise FileServiceError, "PresignedGetUrl for #{file_key} from S3 bucket #{bucket_name} failed: #{e.message}"
  end

  private

  def decrypt_file_contents(tempfile)
    file_contents = tempfile.read

    # Remove tempfile from disk
    tempfile.unlink

    ciphertext_data = JSON.parse(file_contents, symbolize_names: true)
    ciphertext_key = Base64.urlsafe_decode64(ciphertext_data[:key])
    ciphertext = Base64.urlsafe_decode64(ciphertext_data[:data])
    nonce = Base64.urlsafe_decode64(ciphertext_data[:nonce])

    PorkyLib::Symmetric.instance.decrypt(ciphertext_key, ciphertext, nonce)
  end

  def encrypt_file_contents(file, key_id, file_key, options)
    ciphertext_key, ciphertext, nonce = PorkyLib::Symmetric.instance.encrypt(file, key_id)
    write_tempfile(file_contents(ciphertext_key, ciphertext, nonce, options), file_key)
  end

  def file_contents(ciphertext_key, ciphertext, nonce, options)
    if options.is_a?(Hash) && options.key?(:metadata) && !options[:metadata].nil?
      return {
        key: Base64.urlsafe_encode64(ciphertext_key),
        data: Base64.urlsafe_encode64(ciphertext),
        nonce: Base64.urlsafe_encode64(nonce),
        metadata: options[:metadata]
      }.to_json
    end

    {
      key: Base64.urlsafe_encode64(ciphertext_key),
      data: Base64.urlsafe_encode64(ciphertext),
      nonce: Base64.urlsafe_encode64(nonce)
    }.to_json
  end

  def presign_url_expires_in
    PorkyLib::Config.config[:presign_url_expires_in]
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new
  end

  def input_invalid?(file, bucket_name, key_id)
    file.nil? || bucket_name.nil? || key_id.nil?
  end
end
