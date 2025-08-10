# Header Helper Module
# Provides utility methods for working with HTTP headers

module Amethyst
  module Support
    module HeaderHelper
      # Sets header
      def header(key, value)
        @headers[key] = value
      end

      # Returns header
      def header(key)
        @headers[key]
      end

      # Returns true if header exists
      def has_header?(key)
        @headers.has_key? key
      end

      # Returns 'Content-type' header as string
      def content_type : String
        headers["Content-type"]? ? headers["Content-type"].split(";")[0] : ""
      end

      # Sets 'Content-type' header
      def content_type=(ctype : String)
        headers["Content-type"] = ctype
      end

      # Sets 'Content-type' header from file extension
      def ctype_ext=(ext : String)
        ctype = MIME.from_extension(".#{ext}")
        headers["Content-type"] = ctype
      end

      # Returns true if content type matches
      def content_type?(ctype : String)
        ctype == content_type
      end
      
      # Static helper methods
      def self.parse_accept_header(accept : String?) : Array(String)
        return ["*/*"] unless accept
        
        accept.split(",").map do |type|
          type.split(";").first.strip
        end
      end
      
      def self.parse_authorization(auth : String?) : {String, String}?
        return nil unless auth
        
        parts = auth.split(" ", 2)
        return nil unless parts.size == 2
        
        {parts[0], parts[1]}
      end
      
      def self.extract_bearer_token(auth : String?) : String?
        parsed = parse_authorization(auth)
        return nil unless parsed
        
        scheme, token = parsed
        return nil unless scheme.downcase == "bearer"
        
        token
      end
    end
  end
end