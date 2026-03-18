module Notifications
  class NotifyTemplates
    TEMPLATES = %w[self_signup_credentials_email
                   rejected_email_address_email
                   sponsor_credentials_email
                   sponsor_confirmation_plural_email
                   sponsor_confirmation_singular_email
                   sponsor_confirmation_failed_email
                   active_users_signup_survey_email
                   followup_email
                   credentials_expiring_notification_email
                   credentials_sms
                   recap_sms
                   help_menu_sms
                   device_help_other_sms
                   device_help_android_sms
                   device_help_iphone_sms
                   device_help_mac_sms
                   device_help_windows_sms
                   device_help_blackberry_sms
                   device_help_chromebook_sms
                   active_users_signup_survey_sms
                   followup_sms].freeze

    def self.template_hash
      @template_hash ||= begin
        all_templates = Services.notify_client.get_all_templates.collection.inject({}) do |result, template|
          result.merge(template.name => template.id)
        end
        all_templates.slice(*TEMPLATES)
      end
    end

    def self.template(name)
      template_hash.fetch(name.is_a?(Symbol) ? name.to_s : name)
    end

    def self.verify_templates
      names = Services.notify_client.get_all_templates.collection.map(&:name)
      differences = Notifications::NotifyTemplates::TEMPLATES - names
      raise UserSignupError, "Some templates have not been defined in Notify: #{differences.join(', ')}" unless differences.empty?
    end
  end
end
