# frozen_string_literal: true

require 'singleton'

class PorkyLib::Unencrypted::FileService
  include Singleton
  include PorkyLib::FileServiceHelper

  class FileServiceError < StandardError; end
  class FileSizeTooLargeError < StandardError; end

  def read(bucket_name, file_key, options = {})
    tempfile = Tempfile.new

    begin
      object = s3.bucket(bucket_name).object(file_key)
      raise FileSizeTooLargeError, "File size is larger than maximum allowed size of #{max_file_size}" if object.content_length > max_size

      object.download_file(tempfile.path, options)
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      raise FileServiceError, "Attempt to download a file from S3 failed.\n#{e.message}"
    end

    tempfile.read
  end

  def write(file, bucket_name, options = {})
    raise FileServiceError, 'Invalid input. One or more input values is nil' if input_invalid?(file, bucket_name)
    raise FileSizeTooLargeError, "File size is larger than maximum allowed size of #{max_file_size}" if file_size_invalid?(file)

    file_key = generate_file_key(options)
    tempfile = write_tempfile(file_data(file), file_key)

    begin
      perform_upload(bucket_name, file_key, tempfile, options)
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      raise FileServiceError, "Attempt to upload a file to S3 failed.\n#{e.message}"
    end

    file_key
  end

  private

  def input_invalid?(file, bucket_name)
    file.nil? || bucket_name.nil?
  end
end