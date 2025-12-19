require "sensible_logging"
require "sinatra/base"
require "net/http"
require "logger"
require "mail"
require "notifications/client"
require "./lib/loader"

class App < Sinatra::Base
  if ENV.key?("SENTRY_DSN")
    use Sentry::Rack::CaptureExceptions
  end

  register Sinatra::SensibleLogging

  sensible_logging(
    logger: Logger.new($stdout),
  )

  configure do
    set :log_level, Logger::DEBUG
    set :govnotify_token, ENV["GOVNOTIFY_BEARER_TOKEN"]
  end

  configure :production, :staging do
    set :dump_errors, false
  end

  configure :production do
    set :log_level, Logger::INFO
  end

  get "/healthcheck" do
    # When running locally we may use dummy or missing Notify credentials.
    # To avoid external auth calls failing the healthcheck for local testing,
    # set `TEST_LOCAL=1` in your environment (or in `docker-compose.local.yml`).
    # The check still runs in CI/test/staging/production unless explicitly
    # disabled by this variable.
    local_test = ENV["TEST_LOCAL"] == "1" || ENV["TEST_LOCAL"] == "true"

    # Use an explicit positive comparison for readability in conditionals
    if local_test == false
      Notifications::NotifyTemplates.verify_templates
    end

    "Healthy"
  rescue StandardError => e
    logger.error(e.message)
    halt 500, e.message
  end

  post "/user-signup/email-notification" do
    request.body.rewind
    raise UserSignupError, "Unexpected request: \n #{request.body.read}" if request_invalid?(request)

    sns_message = WifiUser::SnsMessage.new(body: request.body.read)

    halt 200, "" if sns_message.type != "Notification" || sns_message.message_id == "AMAZON_SES_SETUP_NOTIFICATION"
    logger.info(sns_message.to_s) if sns_message.type == "SubscriptionConfirmation"

    if sns_message.sponsor_request?
      WifiUser::UseCase::SponsorJourneyHandler.new(sns_message:, logger:).execute
    else
      WifiUser::UseCase::EmailJourneyHandler.new(from_address: sns_message.from_address).execute
    end
  rescue UserSignupError => e
    logger.warn(e.message)
    halt 200, ""
  rescue StandardError => e
    logger.error(e.message)
    raise
  end

  post "/user-signup/sms-notification/notify" do
    request.body.rewind
    halt(401, "") unless is_govnotify_token_valid?

    payload = JSON.parse(request.body.read)
    source = payload["source_number"]
    destination = payload["destination_number"]
    message = payload["message"]
    logger.info("Processing SMS on /user-signup/sms-notification/notify from #{source} to #{destination} with message #{message}")

    raise UserSignupError, "Source number is unavailable" if source.nil?
    raise UserSignupError, "Destination number is unavailable" if destination.nil?
    raise UserSignupError, "SMS loop detected: #{destination}" if numbers_are_equal?(source, destination)
    raise UserSignupError, "Too many messages received from #{source} - (possible bot loop)" if sender_is_repetitive?(source, message)

    WifiUser::UseCase::SmsResponse.new(logger:).execute(
      contact: source,
      sms_content: message,
    )
    ""
  rescue UserSignupError => e
    logger.error(e.message)
    ""
  end

  def numbers_are_equal?(number1, number2)
    WifiUser::PhoneNumber.internationalise(number1) == WifiUser::PhoneNumber.internationalise(number2)
  end

  def sender_is_repetitive?(source, message)
    repetitive_sms_checker = WifiUser::UseCase::RepetitiveSmsChecker.new(
      smslog_model: WifiUser::Repository::Smslog.new,
    )

    repetitive_sms_checker.execute(WifiUser::PhoneNumber.internationalise(source), message)
  end

  def is_govnotify_token_valid?
    env.fetch("HTTP_AUTHORIZATION") == "Bearer #{settings.govnotify_token}"
  end

  def request_invalid?(request)
    !request_valid?(request)
  end

  def request_valid?(request)
    # For now, we only care that the correct header is set to see if we're
    # actually dealing with a notification.
    # There is much more that should be in here.

    request.has_header?("HTTP_X_AMZ_SNS_MESSAGE_TYPE") \
    && request.get_header("HTTP_X_AMZ_SNS_MESSAGE_TYPE") == "Notification"
  end
end
