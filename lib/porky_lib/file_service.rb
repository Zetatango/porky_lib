# frozen_string_literal: true

require 'aws-sdk-s3'
require 'singleton'

class PorkyLib::FileService
  include Singleton

  def read(bucket_name, file_key, options = {})
    tempfile = Tempfile.new
    s3.bucket(bucket_name).object(file_key).download_file(tempfile.path, options)

    decrypt_file_contents(tempfile)
  end

  def write(file, bucket_name, key_id, options = {})
    return if file.nil? || bucket_name.nil? || key_id.nil?

    data = File.file?(file) ? File.read(file) : file
    file_key = SecureRandom.uuid
    tempfile = encrypt_file_contents(data, key_id, file_key)

    perform_upload(bucket_name, file_key, tempfile, options)

    # Remove tempfile from disk
    tempfile.unlink

    file_key
  end

  private

  def perform_upload(bucket_name, file_key, tempfile, options)
    obj = s3.bucket(bucket_name).object(file_key)
    if options.key?(:metadata)
      obj.upload_file(tempfile.path, options[:metadata])
    else
      obj.upload_file(tempfile.path)
    end
  end

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

  def encrypt_file_contents(file, key_id, file_key)
    ciphertext_key, ciphertext, nonce = PorkyLib::Symmetric.instance.encrypt(file, key_id)

    file_contents = {
      key: Base64.urlsafe_encode64(ciphertext_key),
      data: Base64.urlsafe_encode64(ciphertext),
      nonce: Base64.urlsafe_encode64(nonce)
    }.to_json

    write_tempfile(file_contents, file_key)
  end

  def write_tempfile(file_contents, file_key)
    tempfile = Tempfile.new(file_key)
    tempfile << file_contents
    tempfile.close

    tempfile
  end

  def s3
    @s3 ||= Aws::S3::Resource.new
  end
end
