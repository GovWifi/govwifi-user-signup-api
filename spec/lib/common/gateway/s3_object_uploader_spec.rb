describe Common::Gateway::S3ObjectUploader do
  let(:subject) { described_class.new(bucket: bucket, region: region) }
  let(:bucket) { "test-bucket" }
  let(:region) { "eu-west-2" }
  let(:mock_s3_client) { instance_double(Aws::S3::Client) }
  let(:file_path) { "file_path" }
  let(:s3_key) { "s3_key" }

  before do
    allow(Services).to receive(:s3_client).and_return(mock_s3_client)
  end

  describe "#upload" do
    it "ensures the bucket exists, uploads the file, and fetches metadata" do
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

      subject.send(:create_bucket)
    end
  end

  describe "#upload_file" do
    before do
      allow(File).to receive(:open).and_return(StringIO.new("file content"))
    end

    it "uploads the file to S3" do
      expect(mock_s3_client).to receive(:put_object).with(
        bucket: bucket,
        key: s3_key,
        body: instance_of(StringIO),
      )

      subject.send(:upload_file, file_path, s3_key)
    end
  end
end
