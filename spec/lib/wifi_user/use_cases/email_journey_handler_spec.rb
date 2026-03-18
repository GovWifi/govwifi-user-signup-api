describe WifiUser::UseCase::EmailJourneyHandler do
  include_context "fake notify"
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "self_signup_credentials_email", id: "self_signup_credentials_id"),
      instance_double(Notifications::Client::Template, name: "rejected_email_address_email", id: "rejected_email_address_id"),
    ]
  end
  let(:notify_client) { Services.notify_client }
  include_context "simple allow list"

  context "A new user from a government address" do
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

  context "the user is from a non-government address" do
    it "sends a rejection email" do
      expect(WifiUser::EmailSender).to receive(:send_rejected_email_address)
        .with("test@nongov.uk")
      WifiUser::UseCase::EmailJourneyHandler.new(from_address: "test@nongov.uk").execute
    end
    it "does not create a new user" do
      expect {
        WifiUser::UseCase::EmailJourneyHandler.new(from_address: "test@nongov.uk").execute
      }.to change(WifiUser::User, :count).by(0)
    end
  end
end
