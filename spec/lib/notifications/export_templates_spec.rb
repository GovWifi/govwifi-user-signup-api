describe Notifications::ExportTemplates do
  include_context "fake notify"

  let(:templates) do
    [
      instance_double(Notifications::Client::Template, id: "1", type: "email", name: "test_template_1", subject: "Subject1",
                                                       body: "Body", letter_contact_block: "Block", version: 1,
                                                       created_at: Time.now, updated_at: Time.now, created_by: "user1@domain.com"),
      instance_double(Notifications::Client::Template, id: "2", type: "sms", name: "test_template_2", subject: "Subject2",
                                                       body: "Body", letter_contact_block: "Block", version: 1,
                                                       created_at: Time.now, updated_at: Time.now, created_by: "user2@domain.com"),
    ]
  end

  let(:template_hash_collection) do
    [
      { "id" => "1",
        "type" => "email",
        "name" => "test_template_1",
        "subject" => "Subject1",
        "body" => "Body",
        "letter_contact_block" => "Block",
        "version" => 1,
        "created_at" => templates[0].created_at,
        "updated_at" => templates[0].updated_at,
        "created_by" => "user1@domain.com" },
      { "id" => "2",
        "type" => "sms",
        "name" => "test_template_2",
        "subject" => "Subject2",
        "body" => "Body",
        "letter_contact_block" => "Block",
        "version" => 1,
        "created_at" => templates[1].created_at,
        "updated_at" => templates[1].updated_at,
        "created_by" => "user2@domain.com" },
    ]
  end

  let(:bucket) { "test-bucket" }
  let(:key) { "file.json" }

  before do
    allow(ENV).to receive(:fetch).with("S3_NOTIFICATION_TEMPLATES_BUCKET").and_return(bucket)
    stub_const("Notifications::ExportTemplates::KEY", key)
  end

  describe ".execute" do
    context "when upload execute successfully" do
      it "uploads the templates JSON to S3" do
        described_class.execute
        expect(Services.s3_client.get_object(bucket: bucket, key: key).body.read).to eq(template_hash_collection.to_json)
      end
    end
    context "when upload raises an error" do
      before do
        allow_any_instance_of(Common::Gateway::S3ObjectUploader).to receive(:upload).and_raise(StandardError, "upload failed")
      end

      it "raises the error" do
        expect { described_class.execute }.to raise_error(StandardError, "upload failed")
      end
    end
  end

  describe ".templates" do
    it "returns an array of hashes with template attributes" do
      expect(described_class.templates).to match(template_hash_collection)
    end
  end
end
