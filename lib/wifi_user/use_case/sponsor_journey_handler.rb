class WifiUser::UseCase::SponsorJourneyHandler
  include WifiUser::EmailAllowListChecker

  def initialize(sns_message:, logger: Logger.new($stdout))
    @logger = logger
    @sns_message = sns_message
  end

  def execute
    sponsor_address = @sns_message.from_address
    raw_sponsor_address = @sns_message.raw_from_address
    raise UserSignupError, "Unsuccessful sponsor signup attempt: #{sponsor_address}" if invalid_email?(sponsor_address)

    sponsee_addresses = WifiUser::UseCase::EmailSponseesExtractor.new(sns_message: @sns_message).execute
    raise UserSignupError, "Unable to find sponsees: #{sponsor_address}" if sponsee_addresses.empty?

    sponsee_users = sponsee_addresses.map do |sponsee_address|
      WifiUser::User.find_or_create(contact: sponsee_address) { |user| user[:sponsor] = sponsor_address }
    end

    successful_sponsees, failed_sponsees = deliver_to_sponsees(raw_sponsor_address:, sponsee_users:)

    return WifiUser::EmailSender.send_sponsor_failed_confirmation_email(sponsor_address, failed_sponsees) unless failed_sponsees.empty?

    if successful_sponsees.length == 1
      WifiUser::EmailSender.send_sponsor_confirmation_singular(sponsor_address, successful_sponsees.first)
    else
      WifiUser::EmailSender.send_sponsor_confirmation_plural(sponsor_address, successful_sponsees)
    end
  end

private

  def deliver_to_sponsees(raw_sponsor_address:, sponsee_users:)
    sponsee_users.partition do |sponsee_user|
      deliver_to_one_sponsee(raw_sponsor_address:, sponsee_user:)
    end
  end

  def deliver_to_one_sponsee(raw_sponsor_address:, sponsee_user:)
    if sponsee_user.contact.include?("@")
      WifiUser::EmailSender.send_sponsor_email(raw_sponsor_address, sponsee_user)
    else
      WifiUser::SMSSender.send_sponsor_sms(sponsee_user)
    end
  rescue Notifications::Client::BadRequestError => e
    @logger.info(e.message)
    false
  else
    true
  end
end
