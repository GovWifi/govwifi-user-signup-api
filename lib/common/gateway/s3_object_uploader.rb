require "aws-sdk-s3"
require "logger"

module Common
  module Gateway
    class S3ObjectUploader
      attr_reader :bucket, :region, :s3, :logger

      def initialize(bucket:, region: "eu-west-2")
        @bucket = bucket
        @region = region
        @s3 = Services.s3_client(region: region)
        @logger = Logger.new($stdout)
      end

      def upload(file_path, s3_key)
        ensure_bucket_exists
        upload_file(file_path, s3_key)
      rescue Aws::S3::Errors::ServiceError => e
        logger.error "Error uploading file: #{e.message}"
      end

    private

      def ensure_bucket_exists
        return if bucket_exists?

        create_bucket
      end

      def bucket_exists?
        s3.list_buckets.buckets.any? { |b| b.name == bucket }
      end

      def create_bucket
        s3.create_bucket(
          bucket: bucket,
          create_bucket_configuration: { location_constraint: region },
        )
      rescue Aws::S3::Errors::BucketAlreadyOwnedByYou => e
        logger.warn "Bucket '#{bucket}' already exists: #{e.message}"
      end

      def upload_file(file_path, s3_key)
        s3.put_object(
          bucket: bucket,
          key: s3_key,
          body: File.open(file_path, "rb"),
        )
        logger.info "File '#{file_path}' uploaded successfully to #{bucket}/#{s3_key}"
      end
    end
  end
end
