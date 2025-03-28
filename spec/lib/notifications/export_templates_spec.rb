describe Notifications::ExportTemplates do
  subject { described_class }

  let(:response_body) do
    { templates: [
      {
        "body": "Hi\r\n\r\nYou requested a GovWifi username and password recently but haven’t connected yet.\r\n\r\nIf you need help, visit www.wifi.service.gov.uk/help or reply with ‘Help'",
        "created_at": "2024-09-03T15:53:07.255310Z",
        "created_by": "xyz@digital.cabinet-office.gov.uk",
        "id": "58f777da-cadf-4381-88a1-2332551146fb",
        "letter_contact_block": nil,
        "name": "followup_sms",
        "personalisation": {},
        "postage": nil,
        "subject": nil,
        "type": "sms",
        "updated_at": nil,
        "version": 1,
      },
      {
        "body": "Hello,\r\n\r\nYou have been invited to create a GovWifi DEV admin account. \r\n\r\nUse the following link to create your GovWifi admin account:\r\n\r\n((invite_url))",
        "created_at": "2023-09-28T08:38:47.000000Z",
        "created_by": "abc@digital.cabinet-office.gov.uk",
        "id": "5d920a70-f043-416c-8bd6-416da2123b6e",
        "letter_contact_block": nil,
        "name": "invite_email",
        "personalisation": {
          "invite_url": {
            "required": true,
          },
        },
        "postage": nil,
        "subject": "You have been invited to create a GovWifi admin DEV account",
        "type": "email",
        "updated_at": "2024-07-24T11:18:57.874989Z",
        "version": 2,
      },
    ] }
  end

  let(:file_path) { "tmp/template_123.json" }
  let(:file_content) { JSON.parse(File.read(file_path)) }

  before do
    stub_request(:get, "https://api.notifications.service.gov.uk/v2/templates")
      .to_return(status: 200, body: response_body.to_json, headers: {})

    stub_const("Notifications::ExportTemplates::FILE_PATH", file_path)
  end

  context ".execute" do
    before do
      Dir.glob("tmp/template_*.json").each { |file| File.delete(file) }
    end
    it "deletes a file" do
      expect(File).not_to exist(file_path)
    end
  end

  context ".create_file" do
    it "creates a file from tmp" do
      described_class.create_file
      expect(File).to exist(file_path)
    end
  end

  context ".upload_file" do
    before do
      described_class.create_file
    end
    it "upload a file to s3" do
      response = described_class.upload_file
      expect(response.etag).not_to be_nil
      expect(File).to exist(file_path)
      expect(file_content.count).to match(response_body[:templates].count)
    end
  end

  context ".delete_file" do
    before do
      described_class.create_file
    end
    it "delete a file from tmp" do
      described_class.delete_file
      expect(File).not_to exist(file_path)
    end
  end
end
