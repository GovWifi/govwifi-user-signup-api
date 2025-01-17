describe WifiUser::UseCase::SmsResponse do
  include_context "fake notify"
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "credentials_sms", id: "credentials_sms_id"),
      instance_double(Notifications::Client::Template, name: "help_menu_sms", id: "help_menu_sms_id"),
    ]
  end
  let(:notify_client) { Services.notify_client }
  let(:logger) { instance_double(Logger, warn: nil) }
  subject { described_class.new(logger:) }

  before do
    allow(Services).to receive(:notify_client).and_return(notify_client)
  end
  context "With named number" do
    let(:phone_number) { "HIDDENNUMBER" }
    let(:notify_template_id) { "00000000-7777-8888-9999-000000000000" }

    it "does not create a user" do
      expect {
        subject.execute(contact: phone_number, sms_content: "")
      }.to_not change(WifiUser::User, :count)
    end

    it "does not send a message to this number" do
      subject.execute(contact: phone_number, sms_content: "")
      expect(notify_client).not_to have_received(:send_sms)
    end
  end

  context "With valid phone number" do
    it "Creates a user with the phone number with a +44 already" do
      subject.execute(contact: "+447700900003", sms_content: "")
      expect(WifiUser::User.find(contact: "+447700900003")).to_not be nil
    end

    it "Creates a user prepended by +44" do
      subject.execute(contact: "07700900003", sms_content: "")
      expect(WifiUser::User.find(contact: "+447700900003")).to_not be nil
    end

    it "Creates a user prepended by +" do
      subject.execute(contact: "447700900003", sms_content: "")
      expect(WifiUser::User.find(contact: "+447700900003")).to_not be nil
    end

    context "Uses the correct template" do
      it "with a message of Go" do
        subject.execute(contact: "447700900003", sms_content: "Go")
        expect(notify_client).to have_received(:send_sms).with(hash_including(template_id: "credentials_sms_id"))
      end

      it "with a message of Help" do
        subject.execute(contact: "447700900003", sms_content: "Help")
        expect(notify_client).to have_received(:send_sms).with(hash_including(template_id: "help_menu_sms_id"))
      end
    end

    context "For one set of credentials" do
      let(:phone_number) { "+447700900005" }

      it "Sends details to Notify" do
        subject.execute(contact: phone_number, sms_content: "Go")
        user = WifiUser::User.find(contact: phone_number)
        expect(notify_client).to have_received(:send_sms).with(
          phone_number:,
          template_id: "credentials_sms_id",
          personalisation: {
            login: user.username,
            pass: user.password,
          },
        )
      end
    end
  end

  context "With Notifications::Client::BadRequestError" do
    let(:phone_number) { "+447700900003" }

    context "with an email address validation error" do
      before do
        allow(notify_client).to receive(:send_sms).and_raise(Notifications::Client::BadRequestError,
                                                             OpenStruct.new(code: 400, body: "ValidationError"))
      end
      it "doesn't raise error when the email is not valid" do
        expect {
          subject.execute(contact: phone_number, sms_content: "Go")
        }.not_to raise_error
      end
      it "logs the attempt" do
        subject.execute(contact: phone_number, sms_content: "Go")
        expect(logger).to have_received(:warn).with(/Failed to send SMS/)
      end
      it "does not create a user" do
        expect {
          subject.execute(contact: phone_number, sms_content: "Go")
        }.not_to change(WifiUser::User, :count)
      end
    end
    context "with an error that is not a email address validation error" do
      before do
        allow(notify_client).to receive(:send_sms).and_raise(Notifications::Client::ClientError,
                                                             OpenStruct.new(code: 450, body: "Something"))
      end
      it "re-raises the error" do
        expect {
          subject.execute(contact: "447700900003", sms_content: "Go")
        }.to raise_error(Notifications::Client::ClientError)
      end
      it "does not create a user" do
        expect {
          begin
            subject.execute(contact: phone_number, sms_content: "Go")
          rescue StandardError
            # Ignored
          end
        }.not_to change(WifiUser::User, :count)
      end
    end
  end
end
