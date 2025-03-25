require "time"

describe Common::Gateway::S3ObjectUploader do
  let(:bucket) { "StubBucket" }
  let(:file_name) { "spec/fixtures/notification_template.json" }
  let(:s3_key) { "notification_template.json" }

  subject { described_class.new(bucket:) }

  it "uploads a file to S3 successfully" do
    response = subject.upload(file_name, s3_key)
    expect(response.etag).not_to be_nil
  end
end
