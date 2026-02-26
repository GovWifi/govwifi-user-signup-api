class WifiUser::UseCase::SmsResponse
  def initialize(logger: Logger.new($stdout))
    @logger = logger
  end

  def execute(contact:, sms_content:)
    phone_number = WifiUser::PhoneNumber.extract_from(contact)
    return @logger.warn("Unexpected contact detail found #{contact}") if phone_number.nil?

    DB.transaction(retry_on: Sequel::SerializationFailure) do
      login_details = WifiUser::User.find_or_create(contact: phone_number)
      personalisation = { login: login_details[:username], pass: login_details[:password] }

      WifiUser::SMSSender.send_signup_instructions(phone_number:, sms_content:, personalisation:)
    end
  rescue Notifications::Client::BadRequestError => e
    @logger.warn("Failed to send SMS: #{e.message}")
  end
end
