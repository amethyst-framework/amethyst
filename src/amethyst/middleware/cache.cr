require "digest/md5"

module Amethyst
  module Middleware
    abstract class CacheStore
      abstract def get(key : String) : String?
      abstract def set(key : String, value : String, ttl : Time::Span? = nil)
      abstract def delete(key : String)
      abstract def clear
      abstract def stats : Hash(String, Int32 | Int64 | Float64)
    end
    
    class MemoryCache < CacheStore
      struct CacheEntry
        property value : String
        property expires_at : Time?
        property hits : Int64
        property created_at : Time
        property size : Int32
        
        def initialize(@value : String, ttl : Time::Span? = nil)
          @expires_at = ttl ? Time.utc + ttl : nil
          @hits = 0_i64
          @created_at = Time.utc
          @size = @value.bytesize
        end
        
        def expired?
          @expires_at && @expires_at.not_nil! < Time.utc
        end
        
        def hit!
          @hits += 1
        end
      end
      
      @cache : Hash(String, CacheEntry)
      @max_size : Int64
      @current_size : Int64
      @hit_count : Int64
      @miss_count : Int64
      @eviction_count : Int64
      @mutex : Mutex
      
      def initialize(@max_size : Int64 = 100_000_000) # 100MB default
        @cache = Hash(String, CacheEntry).new
        @current_size = 0_i64
        @hit_count = 0_i64
        @miss_count = 0_i64
        @eviction_count = 0_i64
        @mutex = Mutex.new
      end
      
      def get(key : String) : String?
        @mutex.synchronize do
          entry = @cache[key]?
          return nil unless entry
          
          if entry.expired?
            @cache.delete(key)
            @current_size -= entry.size
            @miss_count += 1
            return nil
          end
          
          entry.hit!
          @hit_count += 1
          entry.value
        end
      end
      
      def set(key : String, value : String, ttl : Time::Span? = nil)
        entry = CacheEntry.new(value, ttl)
        
        @mutex.synchronize do
          # Remove existing entry if present
          if existing = @cache[key]?
            @current_size -= existing.size
          end
          
          # Evict entries if needed
          while @current_size + entry.size > @max_size && !@cache.empty?
            evict_lru_entry
          end
          
          @cache[key] = entry
          @current_size += entry.size
        end
      end
      
      def delete(key : String)
        @mutex.synchronize do
          if entry = @cache.delete(key)
            @current_size -= entry.size
          end
        end
      end
      
      def clear
        @mutex.synchronize do
          @cache.clear
          @current_size = 0_i64
        end
      end
      
      def stats : Hash(String, Int32 | Int64 | Float64)
        @mutex.synchronize do
          hit_ratio = @hit_count + @miss_count > 0 ? (@hit_count.to_f64 / (@hit_count + @miss_count)) : 0.0
          
          {
            "entries" => @cache.size,
            "size_bytes" => @current_size,
            "max_size_bytes" => @max_size,
            "hit_count" => @hit_count,
            "miss_count" => @miss_count,
            "hit_ratio" => hit_ratio,
            "eviction_count" => @eviction_count
          }
        end
      end
      
      private def evict_lru_entry
        # Find least recently used entry (lowest hits, oldest creation)
        lru_key = nil
        lru_entry = nil
        
        @cache.each do |key, entry|
          if lru_entry.nil? || 
             entry.hits < lru_entry.not_nil!.hits ||
             (entry.hits == lru_entry.not_nil!.hits && entry.created_at < lru_entry.not_nil!.created_at)
            lru_key = key
            lru_entry = entry
          end
        end
        
        if lru_key && lru_entry
          @cache.delete(lru_key)
          @current_size -= lru_entry.size
          @eviction_count += 1
        end
      end
      
      def cleanup_expired
        @mutex.synchronize do
          expired_keys = [] of String
          
          @cache.each do |key, entry|
            if entry.expired?
              expired_keys << key
            end
          end
          
          expired_keys.each do |key|
            if entry = @cache.delete(key)
              @current_size -= entry.size
            end
          end
          
          expired_keys.size
        end
      end
    end
    
    class ResponseCache < Middleware::Base
      @cache : CacheStore
      @default_ttl : Time::Span
      @cache_key_generator : Http::Request -> String
      @cacheable_checker : Http::Request, Http::Response -> Bool
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @cache = MemoryCache.new
        @default_ttl = 5.minutes
        @cache_key_generator = ->(request : Http::Request) { generate_cache_key(request) }
        @cacheable_checker = ->(request : Http::Request, response : Http::Response) { 
          cacheable?(request, response) 
        }
      end
      
      def call(request) : Http::Response
        # Only cache GET requests
        return @app.call(request) unless request.method.upcase == "GET"
        
        cache_key = @cache_key_generator.call(request)
        
        # Try to get from cache
        if cached_response = @cache.get(cache_key)
          response = deserialize_response(cached_response)
          response.headers["X-Cache"] = "HIT"
          return response
        end
        
        # Not in cache, process request
        response = @app.call(request)
        
        # Cache response if cacheable
        if @cacheable_checker.call(request, response)
          ttl = extract_ttl_from_response(response) || @default_ttl
          serialized = serialize_response(response)
          @cache.set(cache_key, serialized, ttl)
          response.headers["X-Cache"] = "MISS"
        else
          response.headers["X-Cache"] = "SKIP"
        end
        
        response
      end
      
      def set_cache_key_generator(&block : Http::Request -> String)
        @cache_key_generator = block
      end
      
      def set_cacheable_checker(&block : Http::Request, Http::Response -> Bool)
        @cacheable_checker = block
      end
      
      def cache_stats
        @cache.stats
      end
      
      def clear_cache
        @cache.clear
      end
      
      private def generate_cache_key(request : Http::Request) : String
        # Generate cache key from URL, method, and selected headers
        key_parts = [
          request.method.upcase,
          request.path,
          request.query_string || ""
        ]
        
        # Include relevant headers in cache key
        relevant_headers = ["Accept", "Accept-Encoding", "Accept-Language"]
        relevant_headers.each do |header|
          if value = request.headers[header]?
            key_parts << "#{header}:#{value}"
          end
        end
        
        Digest::MD5.hexdigest(key_parts.join("|"))
      end
      
      private def cacheable?(request : Http::Request, response : Http::Response) : Bool
        # Don't cache if response has cache-control no-cache/no-store
        if cache_control = response.headers["Cache-Control"]?
          return false if cache_control.includes?("no-cache") || 
                         cache_control.includes?("no-store") ||
                         cache_control.includes?("private")
        end
        
        # Cache successful responses
        status = response.status
        return false unless status >= 200 && status < 400
        
        # Don't cache responses with Set-Cookie
        return false if response.headers["Set-Cookie"]?
        
        # Don't cache very large responses
        if content_length = response.headers["Content-Length"]?
          return false if content_length.to_i64? && content_length.to_i64.not_nil! > 10_000_000 # 10MB
        end
        
        true
      end
      
      private def extract_ttl_from_response(response : Http::Response) : Time::Span?
        if cache_control = response.headers["Cache-Control"]?
          if max_age_match = cache_control.match(/max-age=(\d+)/)
            return max_age_match[1].to_i32.seconds
          end
        end
        
        if expires = response.headers["Expires"]?
          begin
            expires_time = Time.parse_rfc3339(expires)
            ttl = expires_time - Time.utc
            return ttl if ttl > Time::Span.zero
          rescue
            # Invalid expires header
          end
        end
        
        nil
      end
      
      private def serialize_response(response : Http::Response) : String
        data = {
          status_code: response.status_code,
          status_message: response.status_message,
          headers: response.headers.to_h,
          body: response.body.to_s,
          cached_at: Time.utc.to_rfc3339
        }
        data.to_json
      end
      
      private def deserialize_response(cached_data : String) : Http::Response
        data = JSON.parse(cached_data).as_h
        
        response = Http::Response.new(
          data["status_code"].as_i,
          data["body"].as_s,
          data["status_message"]?.try(&.as_s) || "OK"
        )
        
        # Restore headers
        if headers = data["headers"]?
          headers.as_h.each do |key, value|
            response.headers[key.as_s] = value.as_s
          end
        end
        
        # Add cache metadata
        if cached_at_str = data["cached_at"]?
          cached_at = Time.parse_rfc3339(cached_at_str.as_s)
          age = Time.utc - cached_at
          response.headers["Age"] = age.total_seconds.to_i.to_s
        end
        
        response
      end
    end
    
    # ETag-based caching middleware
    class ETagCache < Middleware::Base
      @weak_etags : Bool
      @cache : Hash(String, String)
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @weak_etags = true
        @cache = Hash(String, String).new
      end
      
      def call(request) : Http::Response
        response = @app.call(request)
        
        # Only process GET/HEAD requests
        return response unless %w[GET HEAD].includes?(request.method.upcase)
        
        # Skip if response already has ETag
        return response if response.headers["ETag"]?
        
        # Generate ETag for response
        if body = response.body
          body_content = body.to_s
          etag = generate_etag(body_content)
          response.headers["ETag"] = etag
          
          # Check if client has cached version
          if if_none_match = request.headers["If-None-Match"]?
            if etag_matches?(if_none_match, etag)
              # Return 304 Not Modified
              not_modified = Http::Response.new(304, "")
              not_modified.headers["ETag"] = etag
              return not_modified
            end
          end
        end
        
        response
      end
      
      private def generate_etag(content : String) : String
        hash = Digest::MD5.hexdigest(content)
        @weak_etags ? "W/\"#{hash}\"" : "\"#{hash}\""
      end
      
      private def etag_matches?(if_none_match : String, etag : String) : Bool
        # Handle multiple ETags in If-None-Match
        if_none_match.split(",").any? do |client_etag|
          client_etag.strip == etag || client_etag.strip == "*"
        end
      end
    end
    
    # Conditional request handling middleware
    class ConditionalGet < Middleware::Base
      def call(request) : Http::Response
        response = @app.call(request)
        
        # Handle If-Modified-Since
        if if_modified_since = request.headers["If-Modified-Since"]?
          if last_modified = response.headers["Last-Modified"]?
            begin
              client_time = Time.parse_rfc3339(if_modified_since)
              server_time = Time.parse_rfc3339(last_modified)
              
              if server_time <= client_time
                not_modified = Http::Response.new(304, "")
                not_modified.headers["Last-Modified"] = last_modified
                return not_modified
              end
            rescue
              # Invalid date format, continue normally
            end
          end
        end
        
        response
      end
    end
  end
end