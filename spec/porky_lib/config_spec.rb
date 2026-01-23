# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::Config, type: :request do
  let(:default_config) do
    { aws_region: '',
      aws_key_id: '',
      aws_key_secret: '',
      aws_client_mock: true,
      max_file_size: 0,
      presign_url_expires_in: 300 }
  end

  before do
    described_class.configure(default_config)
  end

  describe '#logger' do
    before do
      # Reset the logger before each test
      described_class.instance_variable_set(:@logger, nil)
    end

    it 'returns a Logger instance when set directly' do
      custom_logger = Logger.new($stdout)
      described_class.logger = custom_logger
      expect(described_class.logger).to eq(custom_logger)
      expect(described_class.logger).to be_a(Logger)
    end

    it 'returns a default Logger when Rails is not defined' do
      expect(described_class.logger).to be_a(Logger)
    end

    it 'uses Rails.logger when Rails is defined' do
      rails_logger = Logger.new($stdout)
      rails_module = Module.new do
        define_singleton_method(:logger) { rails_logger }
      end
      stub_const('Rails', rails_module)

      described_class.instance_variable_set(:@logger, nil)
      expect(described_class.logger).to eq(rails_logger)
    end

    it 'caches the logger instance' do
      logger1 = described_class.logger
      logger2 = described_class.logger
      expect(logger1.object_id).to eq(logger2.object_id)
    end

    it 'allows replacing the logger' do
      original_logger = described_class.logger
      new_logger = Logger.new($stderr)
      described_class.logger = new_logger
      expect(described_class.logger).to eq(new_logger)
      expect(described_class.logger).not_to eq(original_logger)
    end
  end

  describe '#config' do
    it 'does not set key/value for unknown key' do
      described_class.configure(foo: 'bar')
      expect(described_class.config).to eq(default_config)
    end

    it 'sets aws_region to a known value' do
      described_class.configure(aws_region: 'us-east-1')
      expect(described_class.config).to have_key(:aws_region)
      expect(described_class.config).to have_value('us-east-1')
    end

    it 'sets aws_key_id to a known value' do
      described_class.configure(aws_key_id: 'ABC123')
      expect(described_class.config).to have_key(:aws_key_id)
      expect(described_class.config).to have_value('ABC123')
    end

    it 'sets aws_key_secret to a known value' do
      described_class.configure(aws_key_secret: 's3cr3t')
      expect(described_class.config).to have_key(:aws_key_secret)
      expect(described_class.config).to have_value('s3cr3t')
    end
  end
end
