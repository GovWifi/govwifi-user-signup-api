class WifiUser::UseCase::EmailJourneyHandler
  include WifiUser::EmailAllowListChecker

  def initialize(from_address:)
    @from_address = from_address
  end

  def execute
    if valid_email?(@from_address)
      # Gov (and allow-listed) emails: find or create, always send signup instructions
      user = WifiUser::User.find_or_create(contact: @from_address)
      WifiUser::EmailSender.send_signup_instructions(user)
    else
      # Non-gov: find existing user only (same as original flow). No find_or_create.
      user = WifiUser::User.find(contact: @from_address)

      if user && within_sponsored_reminder_window?(user)
        WifiUser::EmailSender.send_signup_instructions(user)
      elsif user
        WifiUser::EmailSender.send_sponsor_credentials_expired_notification(@from_address)
      else
        WifiUser::EmailSender.send_rejected_email_address(@from_address)
      end
    end
  end

private

  def within_sponsored_reminder_window?(user)
    cutoff = Time.now - 90 * 24 * 60 * 60
    last_activity = user.last_login || user.created_at
    last_activity && last_activity >= cutoff
  end
end
