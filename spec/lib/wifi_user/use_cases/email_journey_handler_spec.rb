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

  # Government emails (find_or_create, always send signup instructions)
  describe "when its a new user from a government address" do
    let(:gov_email) { "test@gov.uk" }

    context "and no user exists yet" do
      it "creates a new user" do
        expect {
          WifiUser::UseCase::EmailJourneyHandler.new(from_address: gov_email).execute
        }.to change(WifiUser::User, :count).by(1)
      end

      it "sends the credentials" do
        WifiUser::UseCase::EmailJourneyHandler.new(from_address: gov_email).execute
        expect(notify_client).to have_received(:send_email)
                                         .with(hash_including(template_id: "self_signup_credentials_id"))
      end
    end

    context "the user already exists" do
      before :each do
        @user = WifiUser::User.create(contact: gov_email)
      end
      it "does not create a new user if one exists" do
        expect {
          WifiUser::UseCase::EmailJourneyHandler.new(from_address: gov_email).execute
        }.to change(WifiUser::User, :count).by(0)
      end

      it "sends the credentials again" do
        WifiUser::UseCase::EmailJourneyHandler.new(from_address: gov_email).execute
        expect(notify_client).to have_received(:send_email)
                                  .with(hash_including(template_id: "self_signup_credentials_id",
                                                       email_address: @user.contact,
                                                       personalisation: {
                                                         username: @user.username,
                                                         password: @user.password,
                                                       }))
      end
    end
  end

  # Non-government emails (find only, no create and  90-day window for sponsored users)
  describe "when the sender is a non-government email" do
    let(:nongov_email) { "test@nongov.uk" }

    context "and no user record exists (e.g. never sponsored)" do
      it "sends a rejection email" do
        expect(WifiUser::EmailSender).to receive(:send_rejected_email_address)
          .with("nongov_email")
        WifiUser::UseCase::EmailJourneyHandler.new(from_address: "nongov_email").execute
      end
      it "does not create a new user" do
        expect {
          WifiUser::UseCase::EmailJourneyHandler.new(from_address: "nongov_email").execute
        }.to change(WifiUser::User, :count).by(0)
      end
    end

    context "and a sponsored user exists with last activity within 90 days" do
      let!(:user) do
        WifiUser::User.create(
          contact: nongov_email,
          sponsor: "sponsor@gov.uk",
          last_login: Time.now - 30 * 24 * 60 * 60, # 30 days ago
        )
      end

      it "sends signup instructions (same as gov journey)" do
        expect(WifiUser::EmailSender).to receive(:send_signup_instructions).with(user)

        described_class.new(from_address: nongov_email).execute
      end

      it "does not create a new user" do
        expect {
          described_class.new(from_address: nongov_email).execute
        }.not_to change(WifiUser::User, :count)
      end
    end

    context "and a sponsored user exists but last activity is beyond 90 days" do
      let!(:user) do
        WifiUser::User.create(
          contact: nongov_email,
          sponsor: "sponsor@gov.uk",
          last_login: Time.now - 120 * 24 * 60 * 60, # 120 days ago
        )
      end

      it "sends sponsor credentials expired notification (no credentials sent)" do
        expect(WifiUser::EmailSender).to receive(:send_sponsor_credentials_expired_notification)
          .with(nongov_email)

        described_class.new(from_address: nongov_email).execute
      end

      it "does not create a new user" do
        expect {
          described_class.new(from_address: nongov_email).execute
        }.not_to change(WifiUser::User, :count)
      end
    end
  end
end
