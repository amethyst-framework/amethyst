module Amethyst
  module Base
    class Logger
      @@instance : Logger?
      
      def self.instance
        @@instance ||= new
      end
      
      def log_string(message : String)
        puts message
      end
      
      def log(message : String, level = :info)
        puts "[#{level.to_s.upcase}] #{message}"
      end
    end
  end
end