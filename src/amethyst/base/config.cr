module Amethyst
  module Base
    class Config
      property app_dir : String = ""
      property namespace : String = ""
      property environment : String = ENV["CRYSTAL_ENV"]? || "development"
      property static_dirs : Array(String) = ["public"]
      
      @@instance : Config?
      
      def self.instance
        @@instance ||= new
      end
    end
  end
end