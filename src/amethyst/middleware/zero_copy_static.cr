module Amethyst
  module Middleware
    class ZeroCopyStatic < Middleware::Base
      @static_dirs : Array(String)
      @file_cache : Hash(String, FileInfo)
      @cache_max_size : Int64
      @cache_current_size : Int64
      @etag_cache : Hash(String, String)
      
      struct FileInfo
        property path : String
        property size : Int64
        property mtime : Time
        property etag : String
        property content_type : String
        
        def initialize(@path : String, @size : Int64, @mtime : Time, @etag : String, @content_type : String)
        end
      end
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        @cache_max_size = 100_000_000_i64
        super(@app)
        @static_dirs = Amethyst::Base::App.settings.static_dirs
        @file_cache = Hash(String, FileInfo).new
        @cache_current_size = 0_i64
        @etag_cache = Hash(String, String).new
      end
      
      def call(request) : Http::Response
        if File.extname(request.path) == ""
          return @app.call(request)
        end
        
        file_path = find_static_file(request.path)
        return Http::Response.new(404, "File not found") unless file_path
        
        file_info = get_file_info(file_path)
        return Http::Response.new(404, "File not found") unless file_info
        
        # Handle conditional requests
        if if_none_match = request.headers["If-None-Match"]?
          if if_none_match.includes?(file_info.etag)
            response = Http::Response.new(304, "")
            response.headers["ETag"] = file_info.etag
            return response
          end
        end
        
        if if_modified_since = request.headers["If-Modified-Since"]?
          begin
            client_time = Time.parse_rfc3339(if_modified_since)
            if file_info.mtime <= client_time
              response = Http::Response.new(304, "")
              response.headers["ETag"] = file_info.etag
              return response
            end
          rescue
            # Invalid date format, continue with normal serving
          end
        end
        
        # Handle range requests for partial content
        if range_header = request.headers["Range"]?
          return handle_range_request(file_info, range_header)
        end
        
        # Serve full file with zero-copy when possible
        serve_file(file_info)
      end
      
      private def find_static_file(file_path : String) : String?
        @static_dirs.each do |dir|
          full_path = File.join(Amethyst::Base::App.settings.app_dir, dir, file_path)
          return full_path if File.file?(full_path)
        end
        nil
      end
      
      private def get_file_info(file_path : String) : FileInfo?
        return nil unless File.exists?(file_path)
        
        stat = File.info(file_path)
        cache_key = file_path
        
        # Check if file info is cached and still valid
        if cached = @file_cache[cache_key]?
          return cached if cached.mtime >= stat.modification_time
        end
        
        # Generate ETag
        etag = generate_etag(file_path, stat)
        content_type = get_content_type(file_path)
        
        file_info = FileInfo.new(
          path: file_path,
          size: stat.size,
          mtime: stat.modification_time,
          etag: etag,
          content_type: content_type
        )
        
        # Cache file info if within limits
        if @cache_current_size + stat.size <= @cache_max_size
          @file_cache[cache_key] = file_info
          @cache_current_size += stat.size
        end
        
        file_info
      end
      
      private def generate_etag(file_path : String, stat : File::Info) : String
        cache_key = "#{file_path}:#{stat.modification_time.to_unix}:#{stat.size}"
        
        if etag = @etag_cache[cache_key]?
          return etag
        end
        
        # Simple ETag based on file path, mtime, and size
        etag = %("#{Digest::MD5.hexdigest(cache_key)}")
        @etag_cache[cache_key] = etag
        
        # Limit ETag cache size
        if @etag_cache.size > 10000
          @etag_cache.clear
        end
        
        etag
      end
      
      private def get_content_type(file_path : String) : String
        ext = File.extname(file_path).downcase
        case ext
        when ".html", ".htm" then "text/html; charset=utf-8"
        when ".css" then "text/css"
        when ".js", ".mjs" then "application/javascript"
        when ".json" then "application/json"
        when ".png" then "image/png"
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".gif" then "image/gif"
        when ".svg" then "image/svg+xml"
        when ".webp" then "image/webp"
        when ".ico" then "image/x-icon"
        when ".txt" then "text/plain; charset=utf-8"
        when ".xml" then "application/xml"
        when ".pdf" then "application/pdf"
        when ".woff", ".woff2" then "font/woff"
        when ".ttf" then "font/ttf"
        when ".otf" then "font/otf"
        else "application/octet-stream"
        end
      end
      
      private def serve_file(file_info : FileInfo) : Http::Response
        response = Http::Response.new(200, "")
        
        # Set headers
        response.headers["Content-Type"] = file_info.content_type
        response.headers["Content-Length"] = file_info.size.to_s
        response.headers["ETag"] = file_info.etag
        response.headers["Last-Modified"] = file_info.mtime.to_rfc3339
        response.headers["Accept-Ranges"] = "bytes"
        
        # Enable compression for text-based files
        if file_info.content_type.starts_with?("text/") || 
           file_info.content_type.includes?("javascript") ||
           file_info.content_type.includes?("json") ||
           file_info.content_type.includes?("xml")
          response.headers["Vary"] = "Accept-Encoding"
        end
        
        # Cache headers for static assets
        if file_info.path.includes?("/assets/") || 
           file_info.content_type.starts_with?("image/") ||
           file_info.content_type.starts_with?("font/")
          response.headers["Cache-Control"] = "public, max-age=31536000, immutable"
        else
          response.headers["Cache-Control"] = "public, max-age=3600"
        end
        
        # Use sendfile for zero-copy when possible
        begin
          file = File.open(file_info.path, "r")
          response.body = file
        rescue ex
          response = Http::Response.new(500, "Internal Server Error")
        end
        
        response
      end
      
      private def handle_range_request(file_info : FileInfo, range_header : String) : Http::Response
        # Parse Range header (e.g., "bytes=0-1023")
        return Http::Response.new(400, "Bad Range Request") unless range_header.starts_with?("bytes=")
        
        range_spec = range_header[6..-1]
        ranges = parse_ranges(range_spec, file_info.size)
        
        return Http::Response.new(416, "Range Not Satisfiable") if ranges.empty?
        
        # For simplicity, handle only single range requests
        if ranges.size > 1
          return serve_file(file_info) # Fall back to full file
        end
        
        range = ranges[0]
        content_length = range[:end] - range[:start] + 1
        
        response = Http::Response.new(206, "")
        response.headers["Content-Type"] = file_info.content_type
        response.headers["Content-Length"] = content_length.to_s
        response.headers["Content-Range"] = "bytes #{range[:start]}-#{range[:end]}/#{file_info.size}"
        response.headers["Accept-Ranges"] = "bytes"
        response.headers["ETag"] = file_info.etag
        
        # Read only the requested range
        begin
          file = File.open(file_info.path, "r")
          file.seek(range[:start])
          content = file.read(content_length)
          file.close
          response.body = content
        rescue ex
          response = Http::Response.new(500, "Internal Server Error")
        end
        
        response
      end
      
      private def parse_ranges(range_spec : String, file_size : Int64) : Array(Hash(Symbol, Int64))
        ranges = [] of Hash(Symbol, Int64)
        
        range_spec.split(",").each do |range_str|
          range_str = range_str.strip
          
          if range_str.includes?("-")
            parts = range_str.split("-", 2)
            start_str = parts[0].strip
            end_str = parts[1].strip
            
            if start_str.empty?
              # Suffix range (e.g., "-500" means last 500 bytes)
              suffix = end_str.to_i64? || 0
              start = Math.max(0, file_size - suffix)
              ranges << {start: start, end: file_size - 1}
            elsif end_str.empty?
              # Prefix range (e.g., "500-" means from byte 500 to end)
              start = start_str.to_i64? || 0
              ranges << {start: start, end: file_size - 1} if start < file_size
            else
              # Full range (e.g., "500-999")
              start = start_str.to_i64? || 0
              end_pos = end_str.to_i64? || file_size - 1
              end_pos = Math.min(end_pos, file_size - 1)
              ranges << {start: start, end: end_pos} if start <= end_pos && start < file_size
            end
          end
        end
        
        ranges
      end
      
      def clear_cache
        @file_cache.clear
        @etag_cache.clear
        @cache_current_size = 0_i64
      end
      
      def cache_stats
        {
          file_cache_size: @file_cache.size,
          etag_cache_size: @etag_cache.size,
          cache_memory_usage: @cache_current_size,
          cache_limit: @cache_max_size
        }
      end
    end
  end
end