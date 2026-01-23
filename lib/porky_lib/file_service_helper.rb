# frozen_string_literal: true

require 'aws-sdk-s3'

module PorkyLib::FileServiceHelper
  class FileServiceError < StandardError; end

  def data_size_invalid?(data)
    data.bytesize > max_size
  end

  def write_tempfile(file_contents, file_key)
    tempfile = Tempfile.new(file_key)
    tempfile << file_contents
    tempfile.close

    tempfile
  end

  def read_file(file)
    raise FileServiceError, 'file cannot be nil' if file.nil?
    return file if !a_file?(file) && contain_null_byte?(file)
    raise FileServiceError, 'The specified file does not exist' unless File.file?(file)

    File.read(file)
  rescue Errno::EACCES
    raise FileServiceError, 'The specified file cannot be read, no permissions'
  end

  def perform_upload(bucket_name, file_key, tempfile, options)
    upload_options = {
      bucket: bucket_name,
      key: file_key,
      body: File.open(tempfile.path, 'rb'),
      metadata: (options[:metadata] if options.key?(:metadata)),
      storage_class: (options[:storage_class] if options.key?(:storage_class))
    }.compact

    s3_client.put_object(upload_options)
  end

  def s3
    @s3 ||= Aws::S3::Resource.new
  end

  def s3_client
    @s3_client ||= Aws::S3::Client.new
  end

  def max_size
    PorkyLib::Config.config[:max_file_size]
  end

  def max_file_size
    {
      B: 1024,
      KB: 1024 * 1024,
      MB: 1024 * 1024 * 1024,
      GB: 1024 * 1024 * 1024 * 1024
    }.each_pair { |symbol, bytes| return "#{(max_size.to_f / (bytes / 1024)).round(2)}#{symbol}" if max_size < bytes }
  end

  def generate_file_key(options)
    options.key?(:directory) ? "#{options[:directory]}/#{SecureRandom.uuid}" : SecureRandom.uuid
  end

  private

  def a_file?(file_or_content)
    !file_or_content.is_a?(String)
  end

  def a_path?(content_or_path)
    return false if contain_null_byte?(content_or_path)

    File.file?(content_or_path)
  end

  def contain_null_byte?(data)
    null_byte = (+"\u0000").force_encoding("ASCII-8BIT")
    data = (+data).force_encoding("ASCII-8BIT")

    data.include?(null_byte)
  end
end
