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
    PorkyLib::Config.configure(default_config)
  end

  it "logger set directly is not nil" do
    PorkyLib::Config.logger = Logger.new(STDOUT)
    expect(PorkyLib::Config.logger).not_to be nil
    expect(PorkyLib::Config.logger).to be_a(Logger)
  end

  it 'config does not set key/value for unknown key' do
    PorkyLib::Config.configure(foo: 'bar')
    expect(PorkyLib::Config.config).to eq(default_config)
  end

  it 'config sets aws_region to a known value' do
    PorkyLib::Config.configure(aws_region: 'us-east-1')
    expect(PorkyLib::Config.config).to have_key(:aws_region)
    expect(PorkyLib::Config.config).to have_value('us-east-1')
  end

  it 'config sets aws_key_id to a known value' do
    PorkyLib::Config.configure(aws_key_id: 'ABC123')
    expect(PorkyLib::Config.config).to have_key(:aws_key_id)
    expect(PorkyLib::Config.config).to have_value('ABC123')
  end

  it 'config sets aws_key_secret to a known value' do
    PorkyLib::Config.configure(aws_key_secret: 's3cr3t')
    expect(PorkyLib::Config.config).to have_key(:aws_key_secret)
    expect(PorkyLib::Config.config).to have_value('s3cr3t')
  end
end
