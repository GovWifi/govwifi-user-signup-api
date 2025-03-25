describe Notifications::ExportTemplates do
  subject { described_class }

  let(:mock_notify_client) { instance_double("Notifications::Client") }
  let(:mock_templates) do
    [
      instance_double("Template", id: "1", type: "email", name: "test_template_1", subject: "Subject1",
                                  body: "Body", letter_contact_block: "Block", version: 1,
                                  created_at: Time.now, updated_at: Time.now, created_by: "user1@domain.com"),
      instance_double("Template", id: "2", type: "sms", name: "test_template_2", subject: "Subject2",
                                  body: "Body", letter_contact_block: "Block", version: 1,
                                  created_at: Time.now, updated_at: Time.now, created_by: "user2@domain.com"),
    ]
  end
  let(:mock_s3_uploader) { instance_double("Common::Gateway::S3ObjectUploader") }
  let(:file_name_regex) { /template_\d{14}\.json/ }
  let(:file_path_regex) { %r{tmp/template_\d{14}\.json} }

  before do
    allow(Services).to receive(:notify_client).and_return(mock_notify_client)
    allow(mock_notify_client).to receive_message_chain(:get_all_templates, :collection).and_return(mock_templates)
    allow(Common::Gateway::S3ObjectUploader).to receive(:new).and_return(mock_s3_uploader)
    allow(mock_s3_uploader).to receive(:upload)
  end

  describe ".execute" do
    it "creates, uploads, and deletes the file" do
      expect_any_instance_of(described_class).to receive(:create_file)
      expect_any_instance_of(described_class).to receive(:upload_file)
      expect_any_instance_of(described_class).to receive(:delete_file)

      described_class.execute
    end
  end

  describe "#create_file" do
    let(:instance) { described_class.new }
    let(:file_content) do
      JSON.generate([
        { "id" => "1",
          "type" => "email",
          "name" => "test_template_1",
          "subject" => "Subject1",
          "body" => "Body",
          "letter_contact_block" => "Block",
          "version" => 1,
          "created_at" => mock_templates.first.created_at,
          "updated_at" => mock_templates.first.updated_at,
          "created_by" => "user1@domain.com" },
        { "id" => "2",
          "type" => "sms",
          "name" => "test_template_2",
          "subject" => "Subject2",
          "body" => "Body",
          "letter_contact_block" => "Block",
          "version" => 1,
          "created_at" => mock_templates.first.created_at,
          "updated_at" => mock_templates.first.updated_at,
          "created_by" => "user2@domain.com" },
      ])
    end

    before do
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:write)
      allow(FileUtils).to receive(:mkdir_p)
    end

    it "writes the templates to a file" do
      expect(FileUtils).to receive(:mkdir_p).with("tmp")
      expect(File).to receive(:write).with(file_path_regex, file_content)
      instance.send(:create_file)
    end
  end

  describe "#upload_file" do
    let(:instance) { described_class.new }

    it "uploads the file to S3" do
      expect(mock_s3_uploader).to receive(:upload).with(file_path_regex, file_name_regex)
      instance.send(:upload_file)
    end
  end

  describe "#delete_file" do
    let(:instance) { described_class.new }

    before do
      allow(File).to receive(:exist?).and_return(true)
    end

    it "deletes the file if it exists" do
      expect(File).to receive(:delete).with(file_path_regex)
      instance.send(:delete_file)
    end
  end
end
