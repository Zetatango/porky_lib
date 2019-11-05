# frozen_string_literal: true

require 'singleton'

class PorkyLib::Unencrypted::FileService
  extend Gem::Deprecate

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

    if file?(file)
      write_file(file, bucket_name, options)
    else
      write_data(file, bucket_name, options)
    end
  end
  deprecate :write, 'write_file or write_data', 2020, 1

  def write_file(file, bucket_name, options = {})
    raise FileServiceError, 'Invalid input. One or more input values is nil' if input_invalid?(file, bucket_name)

    write_data(read_file(file), bucket_name, options)
  end

  def write_data(data, bucket_name, options = {})
    raise FileServiceError, 'Invalid input. One or more input values is nil' if input_invalid?(data, bucket_name)
    raise FileSizeTooLargeError, "Data size is larger than maximum allowed size of #{max_file_size}" if data_size_invalid?(data)

    file_key = generate_file_key(options)
    tempfile = write_tempfile(data, file_key)

    begin
      perform_upload(bucket_name, file_key, tempfile, options)
    rescue Aws::Errors::ServiceError, Seahorse::Client::NetworkingError => e
      raise FileServiceError, "Attempt to upload a file to S3 failed.\n#{e.message}"
    end

    file_key
  end

  private

  def input_invalid?(file_or_data, bucket_name)
    file_or_data.nil? || bucket_name.nil?
  end
end
