require "aws-sdk-s3"

module Common
  module Gateway
    class S3ObjectUploader
      def initialize(bucket:, region: "eu-west-2")
        @bucket = bucket
        @region = region
        @s3 = Services.s3_client(region: region)
        @logger = Logger.new($stdout)
      end

      def upload(file_path, s3_key)
        create_bucket unless buckets.include?(bucket)

        # Upload file
        s3.put_object(
          bucket: bucket,
          key: s3_key,
          body: File.open(file_path, "rb"),
        )
        logger.info "File '#{file_path}' uploaded successfully to #{bucket}/#{s3_key}"

        # Retrieves an object metadata
        s3.head_object(bucket: bucket, key: s3_key)
      rescue Aws::S3::Errors::ServiceError => e
        logger.error "Error uploading file: #{e.message}"
      end

    private

      def create_bucket
        s3.create_bucket(
          bucket: bucket,
          create_bucket_configuration: {
            location_constraint: region,
          },
        )
      rescue Aws::S3::Errors::BucketAlreadyOwnedByYou => e
        logger.error "Error creating a bucket: #{e.message}"
      end

      def buckets
        s3.list_buckets.buckets.map(&:name)
      end

      attr_reader :bucket, :s3, :region, :logger
    end
  end
end
