module Amethyst
  module Base
    class Config
      property :environment
      property :app_dir
      property :namespace
      property :static_dirs

      # Simple configuration class for App

      include Sugar::Klass
      singleton_INSTANCE

      def initialize
        @environment  = "production"
        @app_dir     = ""
        @namespace   = ""
        @raise_http_method_exceptions = true
        @static_dirs = [] of String
      end

      def self.configure(&block)
        yield INSTANCE
      end

      # Configures application with given block
      def configure(&block)
        with self yield self
      end
    end
  end
end
