module Massive
  module Authenticators
    class S3
      def initialize(filename)
        @filename = filename
      end

      def url
        "https://#{Massive.storage_config[:directory]}.s3.amazonaws.com/#{@filename}#{authentication_params}"
      end

      private

      def authentication_params
        if Massive.storage_config[:key] && Massive.storage_config[:secret]
          "?Expires=#{expiration}&AWSAccessKeyId=#{Massive.storage_config[:key]}&Signature=#{signature}"
        end
      end

      def expiration
        @expiration ||= Time.now.to_i + Massive.storage_config[:expiration]
      end

      def signature
        CGI.escape(
          Base64.encode64(
            OpenSSL::HMAC.digest(
              OpenSSL::Digest.new('sha1'),
              Massive.storage_config[:secret],
              "GET\n\n\n#{expiration}\n/#{Massive.storage_config[:directory]}/#{@filename}".encode("UTF-8")
            )
          ).gsub("\n", "")
        )
      end
    end
  end
end
