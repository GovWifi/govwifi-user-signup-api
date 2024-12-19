require_relative "./shared"

RSpec.describe App do
  include_context "fake notify"

  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "sponsor_credentials_email", id: "sponsor_credentials_email_id"),
      instance_double(Notifications::Client::Template, name: "sponsor_confirmation_plural_email", id: "sponsor_confirmation_plural_id"),
      instance_double(Notifications::Client::Template, name: "sponsor_confirmation_singular_email", id: "sponsor_confirmation_singular_id"),
      instance_double(Notifications::Client::Template, name: "sponsor_confirmation_failed_email", id: "sponsor_confirmation_failed_id"),
      instance_double(Notifications::Client::Template, name: "credentials_sms", id: "credentials_sms_id"),
    ]
  end
  include_context "simple allow list"

  describe "POST /user-signup/sms-notification/notify" do
    let(:email_request_headers) { { "HTTP_X_AMZ_SNS_MESSAGE_TYPE" => "Notification" } }
    let(:bucket_name) { "mybucket" }
    let(:object_key) { "mykey" }
    let(:sponsor_address) { "pete@gov.uk" }
    let(:type) { "Notification" }
    let(:messageId) { "123" }
    let(:request_body) do
      FactoryBot.create(:request_body,
                        from: sponsor_address,
                        to: "sponsor@gov.uk",
                        messageId:,
                        type:,
                        bucketName: bucket_name,
                        objectKey: object_key)
    end

    def do_user_signup
      post "/user-signup/email-notification", request_body.to_json, email_request_headers
    end

    def notify_has_sent_email_to(email_address)
      user = WifiUser::User.find(contact: email_address)
      expect(Services.notify_client).to have_received(:send_email).with(
        {
          email_address:,
          personalisation: {
            username: user.username,
            password: user.password,
            sponsor: sponsor_address,
          },
          template_id: "sponsor_credentials_email_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        },
      )
    end

    def notify_has_sent_sms_to(phone_number)
      user = WifiUser::User.find(contact: phone_number)
      expect(Services.notify_client).to have_received(:send_sms).with(
        {
          phone_number:,
          personalisation: {
            login: user.username,
            pass: user.password,
          },
          template_id: "credentials_sms_id",
        },
      )
    end

    describe "Users already exist" do
      before :each do
        FactoryBot.create(:user_details, contact: "john@nongov.uk", sponsor: "john@nongov.uk")
        FactoryBot.create(:user_details, contact: "+447701001111", sponsor: "+447701001111")
        write_email_to_s3(body: "john@nongov.uk\n+447701001111", bucket_name:, object_key:)
      end
      it "does not create any new users" do
        expect {
          do_user_signup
        }.to_not change(WifiUser::User, :count)
      end
      it "sends messages to sponsored users" do
        do_user_signup
        notify_has_sent_email_to "john@nongov.uk"
        notify_has_sent_sms_to("+447701001111")
      end
      it "sends a confirmation email to the sponsor" do
        do_user_signup
        expect(Services.notify_client).to have_received(:send_email).with(
          email_address: sponsor_address,
          personalisation: {
            number_of_accounts: 2,
            contacts: "john@nongov.uk\r\n+447701001111",
          },
          template_id: "sponsor_confirmation_plural_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        )
      end
    end

    describe "A valid sponsor signs up users through email" do
      it "creates two new users" do
        write_email_to_s3(body: "john@nongov.uk\nemma@elsewhere.uk", bucket_name:, object_key:)
        expect {
          do_user_signup
        }.to change(WifiUser::User, :count).by(2)
      end
      it "filters out lines without email addresses" do
        write_email_to_s3(body: "john@nongov.uk\nemma@elsewhere.uk", bucket_name:, object_key:)
        expect {
          do_user_signup
        }.to change(WifiUser::User, :count).by(2)
      end
      it "creates a new user with the correct parameters" do
        write_email_to_s3(body: "john@nongov.uk", bucket_name:, object_key:)
        do_user_signup
        expect(WifiUser::User.find(contact: "john@nongov.uk", sponsor: sponsor_address)).to_not be(nil)
      end
      it "creates a new user, normalising the email address" do
        write_email_to_s3(body: "  John Doe < john@nongov.uk  >  ", bucket_name:, object_key:)
        do_user_signup
        expect(WifiUser::User.find(contact: "john@nongov.uk")).to_not be(nil)
      end
      it "handles html multipart" do
        write_email_to_s3(html_part: "<h1><b>john@nongov.uk</b></h1>", bucket_name:, object_key:)
        do_user_signup
        expect(WifiUser::User.find(contact: "john@nongov.uk")).to_not be(nil)
      end
      it "handles text multipart" do
        write_email_to_s3(text_part: "john@nongov.uk", bucket_name:, object_key:)
        do_user_signup
        expect(WifiUser::User.find(contact: "john@nongov.uk")).to_not be(nil)
      end
      it "sends an email to all email recipients" do
        write_email_to_s3(body: "john@nongov.uk\nemma@elsewhere.uk", bucket_name:, object_key:)
        do_user_signup
        notify_has_sent_email_to "john@nongov.uk"
        notify_has_sent_email_to "emma@elsewhere.uk"
      end
    end

    describe "A valid sponsor signs up users through SMS" do
      it "creates two new users" do
        write_email_to_s3(body: "07701001111\n+447701002222", bucket_name:, object_key:)
        expect {
          do_user_signup
        }.to change(WifiUser::User, :count).by(2)
      end
      it "creates a new user with the correct parameters" do
        write_email_to_s3(body: "+447701001111", bucket_name:, object_key:)
        do_user_signup
        expect(WifiUser::User.find(contact: "+447701001111", sponsor: sponsor_address)).to_not be(nil)
      end
      it "normalises phone numbers" do
        write_email_to_s3(body: "07701001111", bucket_name:, object_key:)
        do_user_signup
        expect(WifiUser::User.find(contact: "+447701001111", sponsor: sponsor_address)).to_not be(nil)
      end
      it "sends SMSes to all users" do
        write_email_to_s3(body: "07701001111\n+447701002222", bucket_name:, object_key:)
        do_user_signup
        notify_has_sent_sms_to("+447701002222")
        notify_has_sent_sms_to("+447701001111")
      end
    end
    describe "sending receipts" do
      it "sends a receipt to the sponsor (plural)" do
        write_email_to_s3(body: "john@nongov.uk\n07701001111", bucket_name:, object_key:)
        do_user_signup
        expect(Services.notify_client).to have_received(:send_email).with(
          email_address: sponsor_address,
          personalisation: {
            number_of_accounts: 2,
            contacts: "john@nongov.uk\r\n+447701001111",
          },
          template_id: "sponsor_confirmation_plural_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        )
      end
      it "sends a receipt to the sponsor (singular)" do
        write_email_to_s3(body: "john@nongov.uk", bucket_name:, object_key:)
        do_user_signup
        expect(Services.notify_client).to have_received(:send_email).with(
          email_address: sponsor_address,
          personalisation: {
            contact: "john@nongov.uk",
          },
          template_id: "sponsor_confirmation_singular_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        )
      end
      it "sends a receipt when a sponsee email has failed to send" do
        write_email_to_s3(body: "07701001111\njohn@nongov.uk", bucket_name:, object_key:)
        error = Notifications::Client::BadRequestError.new(double(body: "Error", code: 400))
        allow(Services.notify_client).to receive(:send_email).with(hash_including(template_id: "sponsor_credentials_email_id")).and_raise error
        allow(Services.notify_client).to receive(:send_sms).with(hash_including(template_id: "credentials_sms_id")).and_raise error

        do_user_signup
        expect(Services.notify_client).to have_received(:send_email).with(
          email_address: sponsor_address,
          personalisation: {
            failedSponsees: "* +447701001111\n* john@nongov.uk",
          },
          template_id: "sponsor_confirmation_failed_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        )
      end
    end

    describe "The sponsor is from a non-government email address" do
      let(:sponsor_address) { "pete@nongov.uk" }
      it "Does not create a user" do
        expect {
          do_user_signup
        }.to_not change(WifiUser::User, :count)
      end
      it "Does not send any emails" do
        expect(Services.notify_client).to_not have_received(:send_email)
      end
    end

    describe "invalid email address" do
      let(:sponsor_address) { "invalid@email@address" }
      it_behaves_like "rejects_email"
    end
    describe "invalid header" do
      let(:email_request_headers) do
        { "HTTP_X_AMZ_SNS_MESSAGE_TYPE" => "Invalid" }
      end
      include_examples "rejects_email"
    end
    describe "type is not a notification" do
      let(:type) { "SubscriptionConfirmation" }
      include_examples "rejects_email"
    end
    describe "messageId=AMAZON_SES_SETUP_NOTIFICATION" do
      let(:messageId) { "AMAZON_SES_SETUP_NOTIFICATION" }
      include_examples "rejects_email"
    end
  end
end
