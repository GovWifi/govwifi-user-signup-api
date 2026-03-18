require "logger"

class Gdpr::Gateway::Userdetails
  SESSION_BATCH_SIZE = 50
  TIME_TO_DELETE = "1 YEAR".freeze
  TIME_TO_NOTIFY = "11 MONTH".freeze
  HEALTH_USER = "HEALTH".freeze

  def initialize
    @logger = Logger.new($stdout)
  end

  def delete_inactive_users
    @logger.info("Starting daily old user deletion")
    now = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    sql = Sequel.lit("((last_login < DATE_SUB(?, INTERVAL #{TIME_TO_DELETE})) OR
                       (last_login IS NULL AND created_at < DATE_SUB(?, INTERVAL #{TIME_TO_DELETE}))) AND
                       username != ?", now, now, HEALTH_USER)

    total = 0
    while (inactive_users = WifiUser::User.where(sql).limit(SESSION_BATCH_SIZE)).count.positive?
      total += inactive_users.delete
    end
    @logger.info("Finished daily old user deletion, #{total} rows affected")
  end

  def obfuscate_sponsors
    @logger.info("Starting sponsor obfuscation")
    DB.run("
      UPDATE userdetails ud1
      LEFT JOIN userdetails as ud2 ON ud1.sponsor = ud2.contact
      SET ud1.sponsor = REPLACE(ud1.sponsor, SUBSTRING_INDEX(ud1.sponsor, '@', '1'), 'user')
      WHERE ud2.username IS NULL
    ")
    @logger.info("Sponsor obfuscation complete")
  end

  def notify_inactive_users
    @logger.info("Starting notification process for users inactive for 11 months")
    now = Time.now.strftime("%Y-%m-%d %H:%M:%S")

    sql = Sequel.lit("((DATE(last_login) = DATE(DATE_SUB(?, INTERVAL #{TIME_TO_NOTIFY}))) OR
                       (last_login IS NULL AND DATE(created_at) = DATE(DATE_SUB(?, INTERVAL #{TIME_TO_NOTIFY})))) AND
                       username != ? AND contact LIKE '%@%'", now, now, HEALTH_USER)

    inactive_users = WifiUser::User.where(sql)
    inactive_users.each { |user| send_notify_email(user) }

    @logger.info("Notified #{inactive_users.count} users")
  end

private

  def send_notify_email(user)
    WifiUser::EmailSender.send_credentials_expiring_notification(user.username, user.contact)
    @logger.info("Email sent to #{user.username} at #{user.contact}")
  rescue Notifications::Client::BadRequestError => e
    handle_email_error(e, user.username, user.contact)
  rescue StandardError => e
    @logger.error(e.message)
  end

  def handle_email_error(error, username, contact)
    if error.message.include? "ValidationError"
      @logger.warn("Failed to send email to #{username} at #{contact}: #{error.message}")
    else
      @logger.error("Unexpected error sending email to #{username} at #{contact}: #{error.message}")
    end
  end
end
