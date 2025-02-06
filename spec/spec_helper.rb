require "logger"
require "factory_bot"
require "rack/test"
require "rspec"
require "simplecov"
require "sequel"
require "timecop"
require "webmock/rspec"
require "shared"
require "ostruct"
ENV["RACK_ENV"] = "test"

require File.expand_path "../app.rb", __dir__

module RSpecMixin
  include Rack::Test::Methods
  def app
    described_class
  end
end

SimpleCov.start
FactoryBot.find_definitions

RSpec.configure do |c|
  c.filter_run_when_matching focus: true

  c.include RSpecMixin
end

module S3Fake
  def self.fake_s3_client
    fake_s3 = {}
    Aws::S3::Client.new(stub_responses: true).tap do |client|
      client.stub_responses(
        :put_object, lambda { |context|
                       bucket = context.params[:bucket]
                       key = context.params[:key]
                       body = context.params[:body]
                       fake_s3[bucket] ||= {}
                       fake_s3[bucket][key] = body
                       {}
                     }
      )
      client.stub_responses(
        :get_object, lambda { |context|
                       bucket = context.params[:bucket]
                       key = context.params[:key]
                       { body: fake_s3.dig(bucket, key) }
                     }
      )
    end
  end
end
RSpec::Support::ObjectFormatter.default_instance.max_formatted_output_length = 1000

RSpec.shared_context "simple allow list" do
  before :each do
    Services.s3_client.put_object(bucket: ENV.fetch("S3_SIGNUP_ALLOWLIST_BUCKET"),
                                  key: ENV.fetch("S3_SIGNUP_ALLOWLIST_OBJECT_KEY"),
                                  body: '^.*@(gov\.uk)$')
  end
end

RSpec.shared_context "fake notify" do
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "self_signup_credentials", id: "self_signup_credentials_id"),
      instance_double(Notifications::Client::Template, name: "rejected_email_address", id: "rejected_email_address_id"),
    ]
  end
  before :each do
    template_collection = instance_double(Notifications::Client::TemplateCollection, collection: templates)
    client = instance_double(Notifications::Client,
                             get_all_templates: template_collection,
                             send_email: nil,
                             send_sms: nil)
    allow(Services).to receive(:notify_client).and_return(client)
  end
end

RSpec.configure do |c|
  c.before(:each) do
    Notifications.send(:remove_const, :NotifyTemplates) if Notifications.const_defined?(:NotifyTemplates)
    load "notifications/notify_templates.rb"

    allow(Services).to receive(:s3_client).and_return(S3Fake.fake_s3_client)
    DB[:smslog].truncate
    DB[:userdetails].truncate
    DB[:notifications].truncate
    c.full_backtrace = true
  end
end
