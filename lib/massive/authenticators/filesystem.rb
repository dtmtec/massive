module Massive
  module Authenticators
    class Filesystem
      def initialize(filename)
        @filename = filename
      end

      def url
        ::File.join(Massive.storage_config[:directory], @filename)
      end
    end
  end
end
