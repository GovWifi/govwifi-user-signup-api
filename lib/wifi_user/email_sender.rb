class WifiUser::EmailSender
  def self.send_rejected_email_address(email_address)
    Services.notify_client.send_email(
      email_address:,
      template_id: Notifications::NotifyTemplates.template(:rejected_email_address_email),
      email_reply_to_id: do_not_reply_email_address_id,
    )
  end

  def self.send_signup_instructions(user)
    Services.notify_client.send_email(
      email_address: user.contact,
      template_id: Notifications::NotifyTemplates.template(:self_signup_credentials_email),
      personalisation: { username: user.username, password: user.password },
      email_reply_to_id: do_not_reply_email_address_id,
    )
  end

  def self.send_sponsor_email(raw_sponsor_address, sponsee_user)
    Services.notify_client.send_email(
      email_address: sponsee_user.contact,
      template_id: Notifications::NotifyTemplates.template(:sponsor_credentials_email),
      personalisation: { username: sponsee_user.username, password: sponsee_user.password, sponsor: raw_sponsor_address },
      email_reply_to_id: do_not_reply_email_address_id,
    )
  end

  def self.send_sponsor_confirmation_plural(sponsor_address, sponsee_users)
    Services.notify_client.send_email(
      email_address: sponsor_address,
      template_id: Notifications::NotifyTemplates.template(:sponsor_confirmation_plural_email),
      personalisation: {
        number_of_accounts: sponsee_users.length,
        contacts: sponsee_users.map(&:contact).join("\r\n"),
      },
      email_reply_to_id: do_not_reply_email_address_id,
    )
  end

  def self.send_sponsor_confirmation_singular(sponsor_address, sponsee_user)
    Services.notify_client.send_email(
      email_address: sponsor_address,
      template_id: Notifications::NotifyTemplates.template(:sponsor_confirmation_singular_email),
      personalisation: {
        contact: sponsee_user.contact,
      },
      email_reply_to_id: do_not_reply_email_address_id,
    )
  end

  def self.send_sponsor_failed_confirmation_email(sponsor_address, failed_sponsees)
    Services.notify_client.send_email(
      email_address: sponsor_address,
      template_id: Notifications::NotifyTemplates.template(:sponsor_confirmation_failed_email),
      personalisation: {
        failedSponsees: failed_sponsees.map { |sponsee| "* #{sponsee.contact}" }.join("\n"),
      },
      email_reply_to_id: do_not_reply_email_address_id,
    )
  end

  def self.send_followup_email(email_address)
    Services.notify_client.send_email(
      email_address:,
      template_id: Notifications::NotifyTemplates.template(:followup_email),
      email_reply_to_id: support_reply_email_address_id,
    )
  end

  def self.send_credentials_expiring_notification(username, contact)
    Services.notify_client.send_email(
      email_address: contact,
      template_id: Notifications::NotifyTemplates.template(:credentials_expiring_notification_email),
      personalisation: {
        username:,
        inactivity_period: "11 months",
      },
      email_reply_to_id: do_not_reply_email_address_id,
    )
  end

  def self.send_active_users_signup_survey(user)
    Services.notify_client.send_email(
      email_address: user.contact,
      template_id: Notifications::NotifyTemplates.template(:active_users_signup_survey_email),
    )
  end

  def self.do_not_reply_email_address_id
    ENV["NOTIFY_DO_NOT_REPLY"] || "0d22d71f-afa3-4c72-8cd4-7716678dbd43"
  end

  def self.support_reply_email_address_id
    ENV["NOTIFY_SUPPORT_REPLY"] || "5619b95b-2f93-4a70-be64-2f2568f8876f"
  end
end
