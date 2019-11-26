# frozen_string_literal: true

require 'aws-sdk-s3'

module PorkyLib::FileServiceHelper
  extend Gem::Deprecate

  class FileServiceError < StandardError; end

  def data_size_invalid?(data)
    data.bytesize > max_size
  end

  def file?(file_or_content)
    a_file?(file_or_content) || a_path?(file_or_content)
  end
  deprecate :file?, :none, 2020, 1

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
    obj = s3.bucket(bucket_name).object(file_key)
    if options.key?(:metadata)
      obj.upload_file(tempfile.path, metadata: options[:metadata])
    else
      obj.upload_file(tempfile.path)
    end
  end

  def s3
    @s3 ||= Aws::S3::Resource.new
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
