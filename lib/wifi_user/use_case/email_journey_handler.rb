class WifiUser::UseCase::EmailJourneyHandler
  include WifiUser::EmailAllowListChecker

  def initialize(from_address:)
    @from_address = from_address
  end

  def execute
    if valid_email?(@from_address)
      user = WifiUser::User.find_or_create(contact: @from_address)
      WifiUser::EmailSender.send_signup_instructions(user)
    else
      user = WifiUser::User.find(contact: @from_address)

      if user
        WifiUser::EmailSender.send_signup_instructions(user)
      else
        WifiUser::EmailSender.send_rejected_email_address(@from_address)
      end
    end
  end
  