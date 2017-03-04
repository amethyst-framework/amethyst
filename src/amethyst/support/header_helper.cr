module Amethyst
  module Support
    module HeaderHelper 

      # Sets header: header "Location", "google.com"
      def header(key, value)
        @headers[key] = value
      end

      # Returns header: header "Location"
      def header(key)
        @headers[key]
      end

      # Returns true if header exists and vice versa
      def has_header?(key)
        @headers.has_key? key
      end

      # Returns 'Content-type' header as string
      def content_type : String
        headers["Content-type"]? ? headers["Content-type"].split(";")[0] : ""
      end

      # Sets 'Content-type' header as string
      def content_type=(ctype : String)
        headers["Content-type"] = ctype
      end

      # Sets 'Content-type' header from file extension: ctype_ext "jpg"
      def ctype_ext=(ext : String)
        unless ctype = Mime.from_ext(ext)
          raise Exceptions::UnknownContentType.new(ext)
        else
          headers["Content-type"] = ctype.as(String)
        end
      end

      # Returns true if content type presented and vice versa
      def content_type?(ctype : String)
        matches = false
        matches = true if ctype == content_type
        matches
      end
    end
  end
end
