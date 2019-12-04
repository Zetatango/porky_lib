# frozen_string_literal: true

require 'porky_lib'

namespace :file do
  desc "Read a file from AWS S3"
  task :read do
    # Optional arguments
    use_mock_client = ENV.fetch('AWS_S3_MOCK_CLIENT', 'true') == 'true'
    max_file_size = ENV.fetch('AWS_S3_MAX_FILE_SIZE', 1_048_576).to_i
    destination = ENV.fetch('DESTINATION', ENV['FILE_KEY'])

    # Required arguments
    arguments = {
      file_key: ENV['FILE_KEY'],
      aws_s3_bucket: ENV['AWS_S3_BUCKET'],
      aws_region: ENV['AWS_REGION'],
      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      aws_access_key: ENV['AWS_ACCESS_KEY']
    }

    # Checks presence of required arguments and configures porky_lib
    check_arguments(arguments)
    setup_porky_lib(arguments, use_mock_client, max_file_size)

    # Reads and writes the file
    message, = PorkyLib::FileService.instance.read(arguments[:aws_s3_bucket], arguments[:file_key])
    file = File.open(destination, 'w')
    file.puts(message)
    file.close

    puts "SUCCESS - Saved file: '#{destination}' with content of the bucket: '#{arguments[:aws_s3_bucket]}' with file_key: '#{arguments[:file_key]}'"
  end

  desc "Write a file to AWS S3"
  task :write do
    # Optional arguments
    use_mock_client = ENV.fetch('AWS_S3_MOCK_CLIENT', 'true') == 'true'
    max_file_size = ENV.fetch('AWS_S3_MAX_FILE_SIZE', 1_048_576).to_i
    storage_class = ENV.fetch('AWS_S3_STORAGE_CLASS', 'STANDARD')
    keep_file_name = ENV.fetch('AWS_S3_KEEP_FILE_NAME', 'true') == 'true'

    # Required arguments
    arguments = {
      file_path: ENV['FILE_PATH'],
      cmk_key_id: ENV['CMK_KEY_ID'],
      aws_s3_bucket: ENV['AWS_S3_BUCKET'],
      aws_region: ENV['AWS_REGION'],
      aws_access_key_id: ENV['AWS_ACCESS_KEY_ID'],
      aws_access_key: ENV['AWS_ACCESS_KEY']
    }

    # Checks presence of required arguments and configures porky_lib
    check_arguments(arguments)
    setup_porky_lib(arguments, use_mock_client, max_file_size)

    write_options = {
      storage_class: storage_class,
      file_name: (File.basename(arguments[:file_path]) if keep_file_name)
    }.compact

    # Creates CMK key with empty tags and stores file
    PorkyLib::Symmetric.instance.create_key([{}], arguments[:cmk_key_id]) unless PorkyLib::Symmetric.instance.cmk_alias_exists?(arguments[:cmk_key_id])
    file_key = PorkyLib::FileService.instance.write_file(arguments[:file_path], arguments[:aws_s3_bucket], arguments[:cmk_key_id], write_options)

    puts "SUCCESS - Created file: '#{arguments[:file_path]}' bucket: '#{arguments[:aws_s3_bucket]}' file_key: '#{file_key}'"
  end
end

private

def check_arguments(arguments)
  nil_arguments = []
  arguments.map { |key, value| nil_arguments.push(key.to_s.upcase) if value.nil? && !key.nil? }
  abort "ERROR - Need to provide as environment variables: #{nil_arguments.join(', ')}" unless nil_arguments.empty?
end

def setup_porky_lib(arguments, use_mock_client, max_file_size)
  PorkyLib::Config.configure(aws_region: arguments[:aws_region],
                             aws_key_id: arguments[:aws_access_key_id],
                             aws_key_secret: arguments[:aws_access_key],
                             aws_client_mock: use_mock_client,
                             max_file_size: max_file_size)
  PorkyLib::Config.initialize_aws
end
