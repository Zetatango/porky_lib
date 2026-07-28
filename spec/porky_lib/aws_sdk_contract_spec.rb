# frozen_string_literal: true

require 'spec_helper'

# Interface contract for the AWS SDK surface PorkyLib depends on.
#
# PorkyLib's suite runs with `aws_client_mock: true`, so its specs never exercise
# the real aws-sdk-kms / aws-sdk-s3 classes -- a mock keeps passing even if a gem
# bump renames or removes a client method, response type, or the error base
# class. Both gems are declared UNVERSIONED in porky_lib.gemspec, so a future
# major could land silently. This spec pins the real interface PorkyLib calls
# (lib/porky_lib/symmetric.rb for KMS, lib/porky_lib/file_service_helper.rb for
# S3) so such a break fails here instead of in production.
#
# Shape-only: method / constant presence + error ancestry, no AWS network calls.
RSpec.describe 'AWS SDK interface contract' do # rubocop:disable RSpec/DescribeClass
  # Client methods PorkyLib invokes (grep the two lib files above to keep in sync).
  let(:kms_methods) { %i[generate_data_key decrypt create_key create_alias list_aliases] }
  let(:s3_client_methods) { %i[head_object get_object put_object delete_object] }

  it 'Aws::KMS::Client responds to every method PorkyLib calls' do
    missing = kms_methods.reject { |m| Aws::KMS::Client.method_defined?(m) }
    expect(missing).to be_empty, "Aws::KMS::Client missing: #{missing.inspect}"
  end

  it 'Aws::S3::Client / Resource respond to every method PorkyLib calls' do
    missing = s3_client_methods.reject { |m| Aws::S3::Client.method_defined?(m) }
    expect(missing).to be_empty, "Aws::S3::Client missing: #{missing.inspect}"
    expect(Aws::S3::Resource.method_defined?(:bucket)).to be(true)
  end

  it 'exposes the KMS response types and credentials class PorkyLib references' do
    expect(defined?(Aws::KMS::Types::GenerateDataKeyResponse)).to eq('constant')
    expect(defined?(Aws::KMS::Types::DecryptResponse)).to eq('constant')
    expect(defined?(Aws::KMS::Types::CreateKeyResponse)).to eq('constant')
    expect(defined?(Aws::Credentials)).to eq('constant')
  end

  it 'keeps KMS service errors rescuable as Aws::Errors::ServiceError' do
    # PorkyLib rescues Aws::Errors::ServiceError broadly and specific KMS errors;
    # the error framework must keep producing ServiceError subclasses.
    expect(Aws::KMS::Errors::NotFoundException).to be < Aws::Errors::ServiceError
    expect(Aws::KMS::Errors::InvalidCiphertextException).to be < Aws::Errors::ServiceError
  end
end
