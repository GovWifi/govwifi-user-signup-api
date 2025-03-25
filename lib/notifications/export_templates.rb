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

    def self.execute
      new.call
    end

    def initialize
      timestamp = Time.now.strftime("%Y%m%d%H%M%S")
      @file_name = "template_#{timestamp}.json"
      @file_path = File.join("tmp", @file_name)
      @logger = Logger.new($stdout)
    end

    def call
      create_file
      upload_file
      delete_file
    end

  private

    def templates
      Services.notify_client.get_all_templates.collection.map do |template|
        TEMPLATE_ATTRIBUTES.each_with_object({}) do |attribute, result|
          result[attribute] = template.send(attribute)
        end
      end
    end

    def create_file
      FileUtils.mkdir_p("tmp")
      File.write(@file_path, templates.to_json)

      @logger.info "Local file '#{@file_path}' created."
    end

    def upload_file
      Common::Gateway::S3ObjectUploader.new(
        bucket: ENV.fetch("S3_NOTIFICATION_TEMPLATES_BUCKET"),
      ).upload(@file_path, @file_name)
    end

    def delete_file
      File.delete(@file_path) if File.exist?(@file_path)
      @logger.info "Local file '#{@file_path}' deleted."
    end
  end
end
