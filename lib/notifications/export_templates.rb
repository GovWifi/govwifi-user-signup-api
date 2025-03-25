require "notifications/client"
require "./lib/common/gateway/s3_object_uploader"
require "./lib/services"
require "logger"

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

    FILE_NAME = "template_#{Time.now.strftime('%Y%m%d%H%M%S')}.json".freeze
    FILE_PATH = File.join("tmp", FILE_NAME)
    def self.execute
      create_file
      upload_file
      delete_file
    end

    def self.templates
      Services.notify_client.get_all_templates.collection.map do |template|
        TEMPLATE_ATTRIBUTES.each_with_object({}) do |attribute, result|
          result[attribute] = template.send(attribute)
        end
      end
    end

    def self.create_file
      File.open(FILE_PATH, "w") { |file| file.write(templates.to_json) }
      logger.info "Local file '#{FILE_PATH}' created."
    end

    def self.upload_file
      Common::Gateway::S3ObjectUploader.new(
        bucket: ENV["S3_NOTIFICATION_TEMPLATES_BUCKET"],
      ).upload(FILE_PATH, FILE_NAME)
    end

    def self.delete_file
      File.delete(FILE_PATH) if File.exist?(FILE_PATH)
      logger.info "Local file '#{FILE_PATH}' deleted."
    end

    def self.logger
      Logger.new($stdout)
    end
  end
end
