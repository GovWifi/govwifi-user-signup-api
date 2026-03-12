describe WifiUser::UseCase::EmailJourneyHandler do
  include_context "fake notify"
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "self_signup_credentials_email", id: "self_signup_credentials_id"),
      instance_double(Notifications::Client::Template, name: "rejected_email_address_email", id: "rejected_email_address_id"),
      instance_double(Notifications::Client::Template, name: "sponsor_credentials_expired_notification_email", id: "sponsor_credentials_expired_notification_id"),
    ]
  end
  let(:notify_client) { Services.notify_client }
  include_context "simple allow list"

  context "when the sender is a government email" do
    it "creates a new user" do
      expect {
        WifiUser::UseCase::EmailJourneyHandler.new(from_address: "test@gov.uk").execute
      }.to change(WifiUser::User, :count).by(1)
    end
    it "sends the credentials" do
      WifiUser::UseCase::EmailJourneyHandler.new(from_address: "test@gov.uk").execute
      expect(notify_client).to have_received(:send_email)
                                         .with(hash_including(template_id: "self_signup_credentials_id"))
    end
  end

  context "The user already exists" do
    before :each do
      @user = WifiUser::User.create(contact: "test@gov.uk")
    end
    it "does not create a new user if one exists" do
      expect {
        WifiUser::UseCase::EmailJourneyHandler.new(from_address: "test@gov.uk").execute
      }.to change(WifiUser::User, :count).by(0)
    end
    it "sends the credentials again" do
      WifiUser::UseCase::EmailJourneyHandler.new(from_address: "test@gov.uk").execute
      expect(notify_client).to have_received(:send_email)
                                 .with(hash_including(template_id: "self_signup_credentials_id",
                                                      email_address: @user.contact,
                                                      personalisation: {
                                                        username: @user.username,
                                                        password: @user.password,
                                                      }))
    end
  end

  context "when the sender is a non-government email" do
    let(:from_address) { "test@nongov.uk" }

    context "and no user exists" do
      it "sends a rejection email and does not create a user" do
        expect(WifiUser::EmailSender).to receive(:send_rejected_email_address).with(from_address)
        expect { described_class.new(from_address:).execute }.not_to change(WifiUser::User, :count)
      end
    end

    context "and a sponsored user exists with last activity within 90 days" do
      let!(:user) do
        WifiUser::User.create(
          contact: from_address,
          sponsor: "sponsor@gov.uk",
          last_login: Time.now - 30 * 24 * 60 * 60,
        )
      end

      it "sends signup instructions" do
        described_class.new(from_address:).execute
        expect(notify_client).to have_received(:send_email).with(hash_including(template_id: "self_signup_credentials_id"))
      end

      it "does not create a new user" do
        expect { described_class.new(from_address:).execute }.not_to change(WifiUser::User, :count)
      end
    end

    context "and a sponsored user exists but last activity is beyond 90 days" do
      before do
        WifiUser::User.create(
          contact: from_address,
          sponsor: "sponsor@gov.uk",
          last_login: Time.now - 120 * 24 * 60 * 60,
        )
      end

      it "sends sponsor credentials expired notification" do
        expect(WifiUser::EmailSender).to receive(:send_sponsor_credentials_expired_notification).with(from_address)
        described_class.new(from_address:).execute
      end

      it "does not create a new user" do
        expect { described_class.new(from_address:).execute }.not_to change(WifiUser::User, :count)
      end
    end
  end
end
