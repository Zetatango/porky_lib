# frozen_string_literal: true

require 'aws-sdk-s3'

module PorkyLib::FileServiceHelper
  def file_size_invalid?(file_or_content)
    if a_file?(file_or_content)
      File.size(file_or_content) > max_size
    else
      file_or_content.bytesize > max_size
    end
  end

  def file_data(file_or_content)
    a_file?(file_or_content) ? File.read(file_or_content) : file_or_content
  end

  def write_tempfile(file_contents, file_key)
    tempfile = Tempfile.new(file_key)
    tempfile << file_contents
    tempfile.close

    tempfile
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
end
