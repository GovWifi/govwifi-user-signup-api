require "aws-sdk-s3"
require "logger"

module Common
  module Gateway
    class S3ObjectUploader
      attr_reader :bucket, :region, :s3, :logger

      def initialize(bucket:, region: "eu-west-2", logger: Logger.new($stdout))
        @bucket = bucket
        @region = region
        @s3 = Services.s3_client(region: region)
        @logger = logger
      end

      def upload(body, key)
        ensure_bucket_exists

        s3.put_object(
          bucket: bucket,
          key: key,
          body: body,
        )
        logger.info "File '#{key}' uploaded successfully to '#{bucket}' bucket"
      end

    private

      def ensure_bucket_exists
        return if bucket_exists?

        create_bucket
      end

      def bucket_exists?
        s3.head_bucket(bucket: bucket)
        true
      rescue Aws::S3::Errors::NotFound
        false
      end

      def create_bucket
        s3.create_bucket(
          bucket: bucket,
          create_bucket_configuration: { location_constraint: region },
        )
        logger.info "Bucket '#{bucket}' created successfully"
      end
    end
  end
end
