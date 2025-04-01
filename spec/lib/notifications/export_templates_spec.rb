describe Notifications::ExportTemplates do
  include_context "fake notify"

  subject { described_class.new }
  let(:templates) do
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
    allow(Common::Gateway::S3ObjectUploader).to receive(:new).and_return(mock_s3_uploader)
    allow(mock_s3_uploader).to receive(:upload)
  end

  describe ".execute" do
    before do
      allow_any_instance_of(described_class).to receive_message_chain(:call)
    end

    it "initializes a new instance and calls #call" do
      expect_any_instance_of(described_class).to receive_message_chain(:call)
      described_class.execute
    end
  end

  describe "#call" do
    it "creates, uploads, and deletes the file" do
      expect(subject).to receive(:create_file).ordered
      expect(subject).to receive(:upload_file).ordered
      expect(subject).to receive(:delete_file).ordered
      subject.call
    end
  end

  describe "#create_file" do
    let(:file_content) do
      JSON.generate([
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
      subject.send(:create_file)
    end
  end

  describe "#upload_file" do
    it "uploads the file to S3" do
      expect(mock_s3_uploader).to receive(:upload).with(file_path_regex, file_name_regex)
      subject.send(:upload_file)
    end
  end

  describe "#delete_file" do
    before do
      allow(File).to receive(:exist?).and_return(true)
    end

    it "deletes the file if it exists" do
      expect(File).to receive(:delete).with(file_path_regex)
      subject.send(:delete_file)
    end
  end
end
