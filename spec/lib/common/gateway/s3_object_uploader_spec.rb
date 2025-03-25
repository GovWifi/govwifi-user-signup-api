describe Common::Gateway::S3ObjectUploader do
  let(:bucket) { "test-bucket" }
  let(:region) { "eu-west-2" }
  let(:logger) { instance_double(Logger, info: nil, error: nil, warn: nil) }
  let(:body) { "some content" }
  let(:key) { "file.json" }

  subject { described_class.new(bucket: bucket, region: region, logger: logger) }

  describe "#upload" do
    context "when the bucket already exists" do
      before do
        subject.s3.create_bucket(bucket:)
      end
      it "uploads the file to an existing bucket" do
        expect(logger).to receive(:info).with(/File 'file.json' uploaded successfully to 'test-bucket' bucket/)
        subject.upload(body, key)
        expect(subject.s3.get_object(bucket: bucket, key: key).body.read).to eq("some content")
      end
    end

    context "when the bucket does not exist" do
      it "creates the bucket" do
        expect(logger).to receive(:info).with(/Bucket 'test-bucket' created successfully/)
        subject.upload(body, key)
        expect { subject.s3.head_bucket(bucket:) }.to_not raise_error
      end
      it "uploads the file" do
        expect(logger).to receive(:info).with(/File 'file.json' uploaded successfully to 'test-bucket' bucket/)
        subject.upload(body, key)
        expect(subject.s3.get_object(bucket: bucket, key: key).body.read).to eq("some content")
      end
    end
  end
end
