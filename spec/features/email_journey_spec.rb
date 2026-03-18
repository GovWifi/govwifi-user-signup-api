require_relative "./shared"

RSpec.describe App do
  include_context "fake notify"
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "self_signup_credentials_email", id: "self_signup_credentials_id"),
      instance_double(Notifications::Client::Template, name: "rejected_email_address_email", id: "rejected_email_address_id"),
    ]
  end
  include_context "simple allow list"

  describe "POST /user-signup/email-notification/notify" do
    let(:email_request_headers) do
      { "HTTP_X_AMZ_SNS_MESSAGE_TYPE" => "Notification" }
    end
    let(:from) { "pete@gov.uk" }
    let(:type) { "Notification" }
    let(:messageId) { "123" }
    let(:request_body) do
      FactoryBot.create(:request_body,
                        from:,
                        messageId:,
                        type:)
    end

    def do_user_signup
      post "/user-signup/email-notification", request_body.to_json, email_request_headers
    end

    describe "A valid user signs up" do
      let(:from) { "john@gov.uk" }
      it "creates a new user" do
        expect {
          do_user_signup
        }.to change(WifiUser::User, :count).by(1)
      end
      it "creates a new user with the correct parameters" do
        do_user_signup
        expect(WifiUser::User.find(contact: "john@gov.uk", sponsor: "john@gov.uk")).to_not be(nil)
      end
      describe "normalise user" do
        let(:from) { "   John Doe < john@gov.uk  >  " }
        it "creates a new user, normalising the email address" do
          do_user_signup
          expect(WifiUser::User.find(contact: "john@gov.uk", sponsor: "john@gov.uk")).to_not be(nil)
        end
      end
      it "sends a message to notify with signup credentials" do
        do_user_signup
        user = WifiUser::User.find(contact: from)
        expect(Services.notify_client).to have_received(:send_email).with(email_address: "john@gov.uk",
                                                                          personalisation: {
                                                                            username: user.username,
                                                                            password: user.password,
                                                                          },
                                                                          template_id: "self_signup_credentials_id",
                                                                          email_reply_to_id: "do_not_reply_email_template_id")
      end
      it "returns 200" do
        do_user_signup
        expect(last_response.body).to eq("")
        expect(last_response).to be_successful
      end
    end

    describe "Notify throws an error" do
      before :each do
        allow(Services.notify_client).to receive(:send_email).and_raise(Notifications::Client::BadRequestError.new(double(body: "Error", code: 400)))
      end
      it "re-raises the error" do
        expect { do_user_signup }.to raise_error(Notifications::Client::BadRequestError)
      end
    end

    describe "the user already exists" do
      let(:from) { "john@gov.uk" }
      before :each do
        @user = FactoryBot.create(:user_details, contact: "john@gov.uk")
      end
      it "does not create another user" do
        expect {
          do_user_signup
        }.to_not change(WifiUser::User, :count)
      end
      it "sends a message to notify" do
        do_user_signup
        expect(Services.notify_client).to have_received(:send_email).with({ email_address: "john@gov.uk",
                                                                            personalisation: {
                                                                              username: @user.username,
                                                                              password: @user.password,
                                                                            },
                                                                            template_id: "self_signup_credentials_id",
                                                                            email_reply_to_id: "do_not_reply_email_template_id" })
      end
    end

    describe "The user is from a non-government email address" do
      let(:from) { "john@non-government.uk" }
      it "Does not create a user" do
        expect {
          do_user_signup
        }.to_not change(WifiUser::User, :count)
      end
      it "Sends a rejection email" do
        do_user_signup
        expect(Services.notify_client).to have_received(:send_email).with(email_address: "john@non-government.uk",
                                                                          template_id: "rejected_email_address_id",
                                                                          email_reply_to_id: "do_not_reply_email_template_id")
      end
    end

    describe "invalid email address" do
      let(:request_body) { FactoryBot.create(:request_body, from: "invalid@email@address") }
      include_examples "rejects_email"
    end
    describe "invalid header" do
      let(:email_request_headers) do
        { "HTTP_X_AMZ_SNS_MESSAGE_TYPE" => "Invalid" }
      end
      let(:request_body) { FactoryBot.create(:request_body) }
      include_examples "rejects_email"
    end
    describe "invalid body" do
      let(:request_body) { { invalid: :hash } }
      include_examples "rejects_email"
    end
    describe "type is not a notification" do
      let(:request_body) { FactoryBot.create(:request_body, type: "SubscriptionConfirmation") }
      include_examples "rejects_email"
    end
    describe "message_id=AMAZON_SES_SETUP_NOTIFICATION" do
      let(:request_body) { FactoryBot.create(:request_body, messageId: "AMAZON_SES_SETUP_NOTIFICATION") }
      include_examples "rejects_email"
    end
  end

  describe "POST /user-signup/email-notification" do
    it "returns 200" do
      post "/user-signup/email-notification", '{"Type":"NOOP"}'
      expect(last_response.body).to eq("")
      expect(last_response).to be_successful
    end
  end
end
