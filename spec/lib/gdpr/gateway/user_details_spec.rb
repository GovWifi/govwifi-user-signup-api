# rubocop:disable Style/DateTime

describe Gdpr::Gateway::Userdetails do
  include_context "fake notify"
  let(:year) { 2024 }
  let(:month) { 5 }
  let(:day) { 10 }
  let(:templates) do
    [
      instance_double(Notifications::Client::Template, name: "credentials_expiring_notification_email", id: "credentials_expiring_notification_email_id"),
      instance_double(Notifications::Client::Template, name: "active_users_signup_survey_sms", id: "active_users_signup_survey_sms_id"),
      instance_double(Notifications::Client::Template, name: "active_users_signup_survey_email", id: "active_users_signup_survey_email_id"),
    ]
  end
  let(:user_details) { DB[:userdetails] }
  let(:notify_client) { Services.notify_client }
  let(:valid_email_regexp) { /^[A-Za-z0-9._%+-]+@gov\.uk$/ }

  before :each do
    ENV["DO_NOT_REPLY"] = "do_not_reply_email_template_id"
    user_details.delete
    Timecop.freeze(Time.local(year, month, day, 18, 0, 0))
  end

  after do
    Timecop.return
  end

  context "Deleting old users" do
    context "Based on last_login" do
      context "Given no inactive users" do
        before do
          FactoryBot.create(:user_details, :sms, last_login: Date.today - 364)
          FactoryBot.create(:user_details, last_login: Date.today - 364)
        end

        it "does not delete any users" do
          expect { subject.delete_inactive_users }.not_to(change { user_details.count })
        end
      end

      describe "Delete in batches" do
        before do
          FactoryBot.create_list(:user_details, 150, last_login: Date.today - 400)
        end
        it "deletes all users" do
          expect { subject.delete_inactive_users }.to change { user_details.count }.from(150).to(0)
        end
      end

      context "Given inactive users" do
        before do
          FactoryBot.create(:user_details, contact: "do_not_delete_1@gov.uk", last_login: Date.today - 364)
          FactoryBot.create(:user_details, contact: "do_not_delete_2@gov.uk", last_login: Date.today - 365)
          FactoryBot.create(:user_details, contact: "delete@gov.uk", last_login: Date.today - 366)
          FactoryBot.create(:user_details, contact: "+001234567890", last_login: Date.today - 366)

          subject.delete_inactive_users
        end

        it "deletes only user records that are at least a year old" do
          expect(user_details.select_map(:contact)).to match_array(%w[do_not_delete_1@gov.uk do_not_delete_2@gov.uk])
        end
      end

      context "Given a HEALTH user" do
        before do
          user_details.insert(username: "HEALTH", last_login: Date.today - 731)
        end

        it "does not delete the HEALTH user" do
          subject.delete_inactive_users
          expect(user_details.select_map(:username)).to include("HEALTH")
        end
      end
    end

    context "Based on created_at" do
      context "Given no inactive users" do
        before do
          FactoryBot.create(:user_details, :not_logged_in, created_at: Date.today)
          FactoryBot.create(:user_details, :not_logged_in, created_at: Date.today - 300)
        end

        it "does not delete any user details" do
          expect { subject.delete_inactive_users }.not_to(change { user_details.count })
        end
      end
      context "Given inactive users" do
        before do
          FactoryBot.create(:user_details, :not_logged_in, contact: "do_not_delete_1@gov.uk", created_at: Date.today - 364)
          FactoryBot.create(:user_details, :not_logged_in, contact: "do_not_delete_2@gov.uk", created_at: Date.today - 365)
          FactoryBot.create(:user_details, :not_logged_in, contact: "delete@gov.uk", created_at: Date.today - 366)
          FactoryBot.create(:user_details, :not_logged_in, contact: "+001234567890", created_at: Date.today - 366)

          subject.delete_inactive_users
        end

        it "deletes only user records that are at least a year old" do
          expect(user_details.select_map(:contact)).to match_array(%w[do_not_delete_1@gov.uk do_not_delete_2@gov.uk])
        end

        it "does not notify the deleted user with an sms" do
          expect(notify_client).to_not have_received(:send_sms)
        end

        context "Given the HEALTH user with an inactive created_at" do
          before do
            user_details.insert(username: "HEALTH", created_at: Date.today - 549)
          end

          it "does not delete the HEALTH user" do
            subject.delete_inactive_users
            expect(user_details.all.map { |s| s.fetch(:username) }).to include("HEALTH")
          end
        end
      end
    end
  end

  context "Obfuscating user details" do
    context "Inactive sponsor" do
      before do
        user_details.insert(username: "bob", sponsor: "sally@gov.uk")
      end

      it "obfuscates the sponsor if the sponsor user record does not exist" do
        subject.obfuscate_sponsors
        expect(user_details.where(username: "bob").get(:sponsor)).to eq("user@gov.uk")
      end

      it "does not obfuscate the sponsor more than once" do
        user_details.insert(
          username: "sally",
          contact: "sally@gov.uk",
          sponsor: "user@gov.uk",
          updated_at: Date.today,
        )

        expect {
          subject.obfuscate_sponsors
        }.not_to(change { user_details.where(username: "sally").get(:updated_at) })
      end
    end

    context "Active sponsor" do
      before do
        user_details.insert(username: "bob", sponsor: "sally@gov.uk")
        user_details.insert(username: "sally", contact: "sally@gov.uk", sponsor: "sally@gov.uk")
      end

      it "does not obfuscate the sponsor if the sponsor user record exists" do
        subject.obfuscate_sponsors
        expect(user_details.where(username: "bob").get(:sponsor)).to eq("sally@gov.uk")
      end
    end

    context "Given nobody sponsored the user" do
      context "Given a mobile signup" do
        it "does not obfuscate the sponsor field" do
          user_details.insert(username: "fred", contact: "0839038939", sponsor: "0839038939")
          subject.obfuscate_sponsors
          expect(user_details.where(username: "fred").get(:sponsor)).to eq("0839038939")
        end
      end

      context "Given an email signup" do
        it "does not obfuscate the sponsor field" do
          user_details.insert(username: "fred", contact: "fred@example.com", sponsor: "fred@example.com")
          subject.obfuscate_sponsors
          expect(user_details.where(username: "fred").get(:sponsor)).to eq("fred@example.com")
        end
      end
    end
  end

  context "Notifying inactive users" do
    let(:eleven_months_ago) do
      DateTime.new(year, month, day, 13, 0, 0) << 11
    end
    it "notifies inactive users" do
      email_user = FactoryBot.create(:user_details, last_login: eleven_months_ago)
      FactoryBot.create(:user_details, :sms, last_login: eleven_months_ago)

      subject.notify_inactive_users

      expect(notify_client).to have_received(:send_email).with(
        email_address: email_user.contact,
        template_id: "credentials_expiring_notification_email_id",
        personalisation: { inactivity_period: "11 months", username: email_user.username },
        email_reply_to_id: "do_not_reply_email_template_id",
      ).once

      expect(notify_client).to_not have_received(:send_sms)
    end

    it "does not notify inactive users" do
      FactoryBot.create(:user_details, last_login: nil)
      subject.notify_inactive_users

      expect(notify_client).not_to have_received(:send_email)
      expect(notify_client).not_to have_received(:send_sms)
    end

    it "does not notify inactive users that are not exactly 11 months inactive" do
      FactoryBot.create(:user_details, last_login: DateTime.new(year, month, day - 1, 13, 0, 0) << 11)
      FactoryBot.create(:user_details, last_login: DateTime.new(year, month, day + 1, 13, 0, 0) << 11)

      subject.notify_inactive_users

      expect(notify_client).not_to have_received(:send_email)
      expect(notify_client).not_to have_received(:send_sms)
    end

    describe "Handling Notify Errors" do
      let(:error) { StandardError.new }
      before :each do
        allow(Services.notify_client).to receive(:send_email).and_raise(error)
        FactoryBot.create(:user_details, last_login: eleven_months_ago)
      end
      it "Unexpected Standard errors are logged with error level" do
        expect_any_instance_of(Logger).to receive(:error)
        subject.notify_inactive_users
      end
      describe "The error is an email validation error" do
        let(:error) do
          response = OpenStruct.new(code: 500, body: "something ValidationError something")
          Notifications::Client::BadRequestError.new(response)
        end
        it "logs the error as a warning" do
          expect_any_instance_of(Logger).to receive(:warn).with(/Failed to send email to/)
          subject.notify_inactive_users
        end
      end
      describe "The error is a more serious error thrown by notify" do
        let(:error) do
          response = OpenStruct.new(code: 500, body: "something else")
          Notifications::Client::BadRequestError.new(response)
        end
        it "logs the error as a error" do
          expect_any_instance_of(Logger).to receive(:error).with(/Unexpected error sending/)
          subject.notify_inactive_users
        end
      end
    end
  end
end

# rubocop:enable Style/DateTime
