require "spec_helper"

describe Massive::Authenticators::S3 do
  let(:filename) { 'some/path/my-filename.png' }
  subject(:authenticator) { described_class.new(filename) }

  after do
    Massive.storage_config = {
      key: nil,
      secret: nil
    }
  end

  context 'when no key/secret are set' do
    it "returns the given url without any authentication params" do
      expect(authenticator.url).to eq("https://#{Massive.storage_config[:directory]}.s3.amazonaws.com/#{filename}")
    end
  end

  context 'when key/secret are set' do
    before do
      Massive.storage_config[:key] = 'some-key'
      Massive.storage_config[:secret] = 'some-secret'
      Time.stub(:now).and_return(Time.parse("2014-05-15T13:25:45Z"))
    end

    def parsed_query(url)
      CGI.parse(URI.parse(url).query || '').with_indifferent_access
    end

    it "returns a url pointing to the proper bucket" do
      expect(URI.parse(authenticator.url).host).to eq("#{Massive.storage_config[:directory]}.s3.amazonaws.com")
    end

    it "returns a url using https" do
      expect(URI.parse(authenticator.url).scheme).to eq("https")
    end

    it "returns a url with the filename as path" do
      expect(URI.parse(authenticator.url).path).to eq("/#{filename}")
    end

    it "returns a url with the expiration as a query string parameter using a timestamped format" do
      now = Time.now.tap { |now| Time.stub(:now).and_return(now) }

      expect(parsed_query(authenticator.url)[:Expires].first.to_i).to eq(now.to_i + Massive.storage_config[:expiration])
    end

    it "returns a url with the AWSAccessKeyId as a query string parameter using the configured key" do
      expect(parsed_query(authenticator.url)[:AWSAccessKeyId].first).to eq(Massive.storage_config[:key])
    end

    it "returns a url with the Signature as a query string parameter properly signing the GET request" do
      expect(parsed_query(authenticator.url)[:Signature].first).to eq("FD38leXqSdFYGYrAXgNF8cX98os=")
    end

    context "when changing the expiration" do
      before do
        Time.stub(:now).and_return(Time.parse("2009-08-01T20:03:27Z"))
      end

      it "returns a url with the Signature properly signing based on the current time" do
        expect(parsed_query(authenticator.url)[:Signature].first).to eq("ehM0n71BUPduV9WwWE73PIMmQYM=")
      end
    end

    context "when changing the secret" do
      before do
        Massive.storage_config[:secret] = 'other-secret'
      end

      it "returns a url with the Signature based the configured secret" do
        expect(parsed_query(authenticator.url)[:Signature].first).to eq("mE6pvT9pRLOUcufs+fX45vbbATQ=")
      end
    end

    context "when changing the key" do
      before do
        Massive.storage_config[:key] = 'other-key'
      end

      it "returns a url with the AWSAccessKeyId as a query string parameter using the configured key" do
        expect(parsed_query(authenticator.url)[:AWSAccessKeyId].first).to eq(Massive.storage_config[:key])
      end
    end

    context "when changing the directory" do
      before do
        Massive.storage_config[:directory] = 'other-directory'
      end

      it "returns a url with the expiration as a query string parameter using a timestamped format" do
        now = Time.now.tap { |now| Time.stub(:now).and_return(now) }

        expect(parsed_query(authenticator.url)[:Expires].first.to_i).to eq(now.to_i + Massive.storage_config[:expiration])
      end

      it "returns a url pointing to the proper bucket" do
        expect(URI.parse(authenticator.url).host).to eq("#{Massive.storage_config[:directory]}.s3.amazonaws.com")
      end

      it "returns a url with the Signature based the configured directory" do
        expect(parsed_query(authenticator.url)[:Signature].first).to eq("f37FDYE7lcewcpApQhFYBEUQjhs=")
      end
    end

    context "when changing the filename" do
      let(:filename) { 'some/other/file.txt' }

      it "returns a url with the filename as path" do
        expect(URI.parse(authenticator.url).path).to eq("/#{filename}")
      end

      it "returns a url with the Signature based the configured directory" do
        expect(parsed_query(authenticator.url)[:Signature].first).to eq("fQCrfdk1FhSRZnecyZ2+Jye2HUY=")
      end
    end
  end
end
