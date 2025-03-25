require "notifications/client"
require "./lib/common/gateway/s3_object_uploader"
require "./lib/services"

module Notifications
  class ExportTemplates
    TEMPLATE_ATTRIBUTES = %w[
      id
      type
      name
      subject
      body
      letter_contact_block
      version
      created_at
      updated_at
      created_by
    ].freeze

    KEY = "notify_template_#{Time.now.strftime('%Y%m%d%H%M%S')}.json".freeze

    def self.execute
      Common::Gateway::S3ObjectUploader.new(
        bucket: ENV.fetch("S3_NOTIFICATION_TEMPLATES_BUCKET"),
      ).upload(templates.to_json, KEY)
    end

    def self.templates
      Services.notify_client.get_all_templates.collection.map do |template|
        TEMPLATE_ATTRIBUTES.each_with_object({}) do |attribute, result|
          result[attribute] = template.send(attribute)
        end
      end
    end
  end
end
