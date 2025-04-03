describe Common::Gateway::S3ObjectUploader do
  let(:subject) { described_class.new(bucket: bucket, region: region) }
  let(:bucket) { "test-bucket" }
  let(:region) { "eu-west-2" }
  let(:mock_s3_client) { instance_double(Aws::S3::Client) }
  let(:mock_logger) { instance_double(Logger, info: nil, error: nil, warn: nil) }
  let(:file_path) { "tmp/file.json" }
  let(:s3_key) { "file.json" }

  before do
    allow(Services).to receive(:s3_client).and_return(mock_s3_client)
    allow(Logger).to receive(:new).and_return(mock_logger)

    # Ensure the file exists before testing
    FileUtils.mkdir_p(File.dirname(file_path))
    File.write(file_path, "test content")
  end

  after do
    # Clean up the test file after running
    File.delete(file_path) if File.exist?(file_path)
  end

  describe "#upload" do
    it "ensures the bucket exists and uploads the file" do
      expect(subject).to receive(:ensure_bucket_exists).ordered
      expect(subject).to receive(:upload_file).with(file_path, s3_key).ordered

      subject.upload(file_path, s3_key)
    end
  end

  describe "#bucket_exists?" do
    it "returns true if the bucket exists" do
      allow(mock_s3_client).to receive(:list_buckets).and_return(
        double(buckets: [double(name: bucket)]),
      )
      expect(subject.send(:bucket_exists?)).to be true
    end

    it "returns false if the bucket does not exist" do
      allow(mock_s3_client).to receive(:list_buckets).and_return(
        double(buckets: []),
      )
      expect(subject.send(:bucket_exists?)).to be false
    end
  end

  describe "#create_bucket" do
    it "creates the bucket if it does not exist" do
      expect(mock_s3_client).to receive(:create_bucket).with(
        bucket: bucket,
        create_bucket_configuration: { location_constraint: region },
      )
      expect(mock_logger).to receive(:info).with(/Bucket 'test-bucket' created/)
      subject.send(:create_bucket)
    end
    it "logs a warning if bucket already exists" do
      allow(mock_s3_client).to receive(:create_bucket).and_raise(Aws::S3::Errors::BucketAlreadyOwnedByYou.new(nil, "Create error"))
      expect(mock_logger).to receive(:warn).with(/Bucket 'test-bucket' already exists: Create error/)
      subject.send(:create_bucket)
    end
  end

  describe "#upload_file" do
    let(:uploader_action) { subject.send(:upload_file, file_path, s3_key) }

    context "success" do
      it "uploads the file to S3" do
        expect(mock_s3_client).to receive(:put_object).with(
          bucket: bucket,
          key: s3_key,
          body: instance_of(File),
        )
        expect(File.exist?(file_path)).to be true
        expect(mock_logger).to receive(:info).with(/File 'tmp\/file.json' uploaded successfully to test-bucket\/file.json/)
        uploader_action
      end
    end

    context "error" do
      before do
        allow(mock_s3_client).to receive(:put_object).and_raise(Aws::S3::Errors::ServiceError.new(nil, "Upload error"))
      end

      it "logs an error if upload fails" do
        expect(File.exist?(file_path)).to be true
        expect { uploader_action }.to raise_error(Aws::S3::Errors::ServiceError)
      end
    end
  end
end
