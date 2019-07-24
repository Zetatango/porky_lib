# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PorkyLib::Config, type: :request do
  let(:default_config) do
    { aws_region: '',
      aws_key_id: '',
      aws_key_secret: '',
      aws_client_mock: true,
      max_file_size: 0 }
  end

  before do
    described_class.configure(default_config)
  end

  it "logger set directly is not nil" do
    described_class.logger = Logger.new(STDOUT)
    expect(described_class.logger).not_to be nil
    expect(described_class.logger).to be_a(Logger)
  end

  it 'config does not set key/value for unknown key' do
    described_class.configure(foo: 'bar')
    expect(described_class.config).to eq(default_config)
  end

  it 'config sets aws_region to a known value' do
    described_class.configure(aws_region: 'us-east-1')
    expect(described_class.config).to have_key(:aws_region)
    expect(described_class.config).to have_value('us-east-1')
  end

  it 'config sets aws_key_id to a known value' do
    described_class.configure(aws_key_id: 'ABC123')
    expect(described_class.config).to have_key(:aws_key_id)
    expect(described_class.config).to have_value('ABC123')
  end

  it 'config sets aws_key_secret to a known value' do
    described_class.configure(aws_key_secret: 's3cr3t')
    expect(described_class.config).to have_key(:aws_key_secret)
    expect(described_class.config).to have_value('s3cr3t')
  end
end
