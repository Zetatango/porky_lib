# frozen_string_literal: true

class PorkyLib::Config
  @aws_region = ''
  @aws_key_id = ''
  @aws_key_secret = ''
  @aws_client_mock = false
  @max_file_size = 0
  @presign_url_expires_in = 300 # 5 minutes

  @config = {
    aws_region: @aws_region,
    aws_key_id: @aws_key_id,
    aws_key_secret: @aws_key_secret,
    aws_client_mock: @aws_client_mock,
    max_file_size: @max_file_size,
    presign_url_expires_in: @presign_url_expires_in
  }

  @allowed_config_keys = @config.keys

  def self.configure(options = {})
    options.each { |key, value| @config[key.to_sym] = value if @allowed_config_keys.include? key.to_sym }
  end

  def self.initialize_aws
    Aws.config.update(
      region: @config[:aws_region],
      credentials: Aws::Credentials.new(
        @config[:aws_key_id],
        @config[:aws_key_secret]
      )
    )
  end

  class << self
    attr_reader :config
  end

  def self.logger
    @logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
    @logger
  end

  class << self
    attr_writer :logger
  end
end
