describe WifiUser::UseCase::SponsorJourneyHandler do
  include_context "fake notify"
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "sponsor_credentials_email", id: "sponsor_credentials_email_id"),
      instance_double(Notifications::Client::Template, name: "sponsor_confirmation_plural_email", id: "sponsor_confirmation_plural_email_id"),
      instance_double(Notifications::Client::Template, name: "sponsor_confirmation_singular_email", id: "sponsor_confirmation_singular_email_id"),
      instance_double(Notifications::Client::Template, name: "sponsor_confirmation_failed_email", id: "sponsor_confirmation_failed_email_id"),
      instance_double(Notifications::Client::Template, name: "credentials_sms", id: "credentials_sms_id"),
    ]
  end
  include_context "simple allow list"

  let(:notify_client) { Services.notify_client }
  let(:bucket_name) { "mybucket" }
  let(:object_key) { "object_key" }
  let(:raw_sponsor_address) { "pete <pete@gov.uk>" }
  let(:sponsor_address) { Mail::Address.new(raw_sponsor_address).address }
  let(:type) { "Notification" }
  let(:messageId) { "123" }
  let(:request_body) do
    FactoryBot.create(:request_body,
                      from: raw_sponsor_address,
                      to: "sponsor@gov.uk",
                      messageId:,
                      type:,
                      bucketName: bucket_name,
                      objectKey: object_key)
  end
  let(:sns_message) { WifiUser::SnsMessage.new(body: request_body.to_json) }

  context "the user is from a non-government address" do
    let(:raw_sponsor_address) { "test@nongov.uk" }
    it "raises an error" do
      expect {
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      }.to raise_error(UserSignupError, /Unsuccessful sponsor signup attempt/)
    end
    it "does not create a new user" do
      expect {
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      }.to raise_error(UserSignupError).and change(WifiUser::User, :count).by(0)
    end
  end

  context "there are no sponsees" do
    before :each do
      write_email_to_s3(body: "something\nsomething else\nnothing", bucket_name:, object_key:)
    end
    it "raises an error" do
      expect {
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      }.to raise_error(UserSignupError, /Unable to find sponsees:/)
    end
    it "does not create a new user" do
      expect {
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      }.to raise_error(UserSignupError).and change(WifiUser::User, :count).by(0)
    end
  end

  context "successful sponsoring" do
    before :each do
      write_email_to_s3(body: "something\n 077 01 00 1111\n  dave@nongov.uk ", bucket_name:, object_key:)
    end
    it "creates two users" do
      expect {
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      }.to change(WifiUser::User, :count).by(2)
    end
    it "creates users with the correct parameters" do
      WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      expect(WifiUser::User.find(contact: "+447701001111", sponsor: sponsor_address)).to_not be_nil
      expect(WifiUser::User.find(contact: "dave@nongov.uk", sponsor: sponsor_address)).to_not be_nil
    end
    it "sends an email to the sponsee" do
      WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      user = WifiUser::User.find(contact: "dave@nongov.uk", sponsor: sponsor_address)
      expect(notify_client).to have_received(:send_email).with(
        {
          email_address: "dave@nongov.uk",
          personalisation: {
            username: user.username,
            password: user.password,
            sponsor: raw_sponsor_address,
          },
          template_id: "sponsor_credentials_email_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        },
      )
    end
    it "sends an sms to the sponsee" do
      WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      user = WifiUser::User.find(contact: "+447701001111", sponsor: sponsor_address)
      expect(Services.notify_client).to have_received(:send_sms).with(
        {
          phone_number: "+447701001111",
          personalisation: {
            login: user.username,
            pass: user.password,
          },
          template_id: "credentials_sms_id",
        },
      )
    end
    it "sends a confirmation email to the sponsor" do
      WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
      expect(Services.notify_client).to have_received(:send_email).with(
        email_address: sponsor_address,
        personalisation: {
          number_of_accounts: 2,
          contacts: "+447701001111\r\ndave@nongov.uk",
        },
        template_id: "sponsor_confirmation_plural_email_id",
        email_reply_to_id: "do_not_reply_email_template_id",
      )
    end
    context "the sponsor email includes duplicate contacts" do
      before :each do
        write_email_to_s3(body: "dave@nongov.uk\n07701001111\ndave@nongov.uk\n07701001111", bucket_name:, object_key:)
      end

      it "sends credentials once per unique contact" do
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute

        expect(notify_client).to have_received(:send_email).with(
          hash_including(email_address: "dave@nongov.uk", template_id: "sponsor_credentials_email_id"),
        ).once
        expect(Services.notify_client).to have_received(:send_sms).with(
          hash_including(phone_number: "+447701001111", template_id: "credentials_sms_id"),
        ).once
      end
    end
    context "a user already exists but has not been sponsored" do
      before :each do
        @user = WifiUser::User.create(contact: "test@gov.uk")
        write_email_to_s3(body: "test@gov.uk", bucket_name:, object_key:)
      end
      it "does not create a new user" do
        expect {
          WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
        }.to_not change(WifiUser::User, :count)
      end
      it "sends the credentials of the existing user" do
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
        expect(notify_client).to have_received(:send_email).with(
          {
            email_address: "test@gov.uk",
            personalisation: {
              username: @user.username,
              password: @user.password,
              sponsor: raw_sponsor_address,
            },
            template_id: "sponsor_credentials_email_id",
            email_reply_to_id: "do_not_reply_email_template_id",
          },
        )
      end
    end
    context "only one sponsee" do
      before :each do
        write_email_to_s3(body: "dave@nongov.uk", bucket_name:, object_key:)
      end
      it "sends a singular confirmation email to the sponsor" do
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
        expect(Services.notify_client).to have_received(:send_email).with(
          email_address: sponsor_address,
          personalisation: {
            contact: "dave@nongov.uk",
          },
          template_id: "sponsor_confirmation_singular_email_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        )
      end
    end
    context "A sponsee cannot be contacted" do
      before :each do
        error = Notifications::Client::BadRequestError.new(double(body: "ValidationError", code: 200))
        allow(WifiUser::EmailSender).to receive(:send_sponsor_email).and_raise error
        allow(WifiUser::SMSSender).to receive(:send_sponsor_sms).and_raise error
      end
      it "sends a failure confirmation email to the sponsor" do
        WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:).execute
        expect(Services.notify_client).to have_received(:send_email).with(
          email_address: sponsor_address,
          personalisation: {
            failedSponsees: "* +447701001111\n* dave@nongov.uk",
          },
          template_id: "sponsor_confirmation_failed_email_id",
          email_reply_to_id: "do_not_reply_email_template_id",
        )
      end
    end
  end
end
