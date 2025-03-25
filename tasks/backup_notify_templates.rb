desc "Export All Notify Templates to S3"

task :backup_notify_templates do
  require "./lib/notifications/export_templates"

  Notifications::ExportTemplates.execute
rescue StandardError => e
  abort e.message
end
