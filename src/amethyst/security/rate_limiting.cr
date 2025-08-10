require "redis"

module Amethyst
  module Security
    # Rate limiting strategies
    enum RateLimitStrategy
      FixedWindow
      SlidingWindow
      TokenBucket
      LeakyBucket
    end
    
    # Rate limit store interface
    abstract class RateLimitStore
      abstract def get(key : String) : Hash(String, Int32 | Int64)?
      abstract def set(key : String, data : Hash(String, Int32 | Int64), ttl : Time::Span)
      abstract def increment(key : String, field : String, amount : Int32 = 1) : Int32
      abstract def delete(key : String)
      abstract def exists?(key : String) : Bool
      abstract def cleanup_expired
    end
    
    # Memory-based rate limit store
    class MemoryRateLimitStore < RateLimitStore
      @data : Hash(String, {data: Hash(String, Int32 | Int64), expires_at: Time})
      @mutex : Mutex
      
      def initialize
        @data = Hash(String, {data: Hash(String, Int32 | Int64), expires_at: Time}).new
        @mutex = Mutex.new
        
        # Start cleanup task
        start_cleanup_task
      end
      
      def get(key : String) : Hash(String, Int32 | Int64)?
        @mutex.synchronize do
          entry = @data[key]?
          return nil unless entry
          
          if entry[:expires_at] < Time.utc
            @data.delete(key)
            return nil
          end
          
          entry[:data]
        end
      end
      
      def set(key : String, data : Hash(String, Int32 | Int64), ttl : Time::Span)
        @mutex.synchronize do
          @data[key] = {
            data: data,
            expires_at: Time.utc + ttl
          }
        end
      end
      
      def increment(key : String, field : String, amount : Int32 = 1) : Int32
        @mutex.synchronize do
          entry = @data[key]?
          
          unless entry
            # Key doesn't exist, create it with default TTL
            @data[key] = {
              data: {field => amount},
              expires_at: Time.utc + 1.hour
            }
            return amount
          end
          
          # Key exists, increment field
          current_value = entry[:data][field]?.try(&.as(Int32)) || 0
          new_value = current_value + amount
          entry[:data][field] = new_value
          
          new_value
        end
      end
      
      def delete(key : String)
        @mutex.synchronize do
          @data.delete(key)
        end
      end
      
      def exists?(key : String) : Bool
        @mutex.synchronize do
          entry = @data[key]?
          return false unless entry
          
          if entry[:expires_at] < Time.utc
            @data.delete(key)
            return false
          end
          
          true
        end
      end
      
      def cleanup_expired
        @mutex.synchronize do
          expired_keys = [] of String
          current_time = Time.utc
          
          @data.each do |key, entry|
            if entry[:expires_at] < current_time
              expired_keys << key
            end
          end
          
          expired_keys.each { |key| @data.delete(key) }
          expired_keys.size
        end
      end
      
      def stats
        @mutex.synchronize do
          {
            total_keys: @data.size,
            expired_keys: @data.count { |_, entry| entry[:expires_at] < Time.utc }
          }
        end
      end
      
      private def start_cleanup_task
        spawn do
          loop do
            sleep 5.minutes
            cleanup_expired
          end
        end
      end
    end
    
    # Redis-based rate limit store (optional)
    class RedisRateLimitStore < RateLimitStore
      @redis : Redis
      @key_prefix : String
      
      def initialize(@redis : Redis, @key_prefix : String = "rate_limit:")
      end
      
      def get(key : String) : Hash(String, Int32 | Int64)?
        full_key = "#{@key_prefix}#{key}"
        
        begin
          data = @redis.hgetall(full_key)
          return nil if data.empty?
          
          result = Hash(String, Int32 | Int64).new
          data.each_slice(2) do |slice|
            field, value = slice
            result[field.to_s] = value.to_s.to_i64
          end
          
          result
        rescue ex
          Base::App.logger.log_string "Redis rate limit get error: #{ex.message}"
          nil
        end
      end
      
      def set(key : String, data : Hash(String, Int32 | Int64), ttl : Time::Span)
        full_key = "#{@key_prefix}#{key}"
        
        begin
          # Use pipeline for atomic operations
          @redis.multi do |multi|
            multi.del(full_key)
            data.each do |field, value|
              multi.hset(full_key, field, value.to_s)
            end
            multi.expire(full_key, ttl.total_seconds.to_i)
          end
        rescue ex
          Base::App.logger.log_string "Redis rate limit set error: #{ex.message}"
        end
      end
      
      def increment(key : String, field : String, amount : Int32 = 1) : Int32
        full_key = "#{@key_prefix}#{key}"
        
        begin
          result = @redis.hincrby(full_key, field, amount)
          
          # Set expiration if this is a new key
          if result == amount
            @redis.expire(full_key, 3600) # 1 hour default
          end
          
          result.to_i32
        rescue ex
          Base::App.logger.log_string "Redis rate limit increment error: #{ex.message}"
          0
        end
      end
      
      def delete(key : String)
        full_key = "#{@key_prefix}#{key}"
        
        begin
          @redis.del(full_key)
        rescue ex
          Base::App.logger.log_string "Redis rate limit delete error: #{ex.message}"
        end
      end
      
      def exists?(key : String) : Bool
        full_key = "#{@key_prefix}#{key}"
        
        begin
          @redis.exists(full_key) > 0
        rescue ex
          Base::App.logger.log_string "Redis rate limit exists error: #{ex.message}"
          false
        end
      end
      
      def cleanup_expired
        # Redis handles expiration automatically
        0
      end
    end
    
    # Rate limiter implementations
    abstract class RateLimiter
      @store : RateLimitStore
      @limit : Int32
      @window : Time::Span
      
      def initialize(@store : RateLimitStore, @limit : Int32, @window : Time::Span)
      end
      
      abstract def check_limit(key : String) : {allowed: Bool, count: Int32, reset_at: Time}
      abstract def reset_limit(key : String)
    end
    
    # Fixed window rate limiter
    class FixedWindowRateLimiter < RateLimiter
      def check_limit(key : String) : {allowed: Bool, count: Int32, reset_at: Time}
        current_window = get_current_window
        window_key = "#{key}:#{current_window}"
        
        data = @store.get(window_key) || Hash(String, Int32 | Int64).new
        current_count = data["count"]?.try(&.as(Int32)) || 0
        
        if current_count >= @limit
          reset_at = Time.unix(current_window) + @window
          return {allowed: false, count: current_count, reset_at: reset_at}
        end
        
        # Increment counter
        new_count = @store.increment(window_key, "count")
        
        # Set expiration for the window
        if new_count == 1
          @store.set(window_key, {"count" => new_count}, @window)
        end
        
        reset_at = Time.unix(current_window) + @window
        {allowed: true, count: new_count, reset_at: reset_at}
      end
      
      def reset_limit(key : String)
        current_window = get_current_window
        window_key = "#{key}:#{current_window}"
        @store.delete(window_key)
      end
      
      private def get_current_window : Int64
        (Time.utc.to_unix / @window.total_seconds).to_i64 * @window.total_seconds.to_i64
      end
    end
    
    # Sliding window rate limiter
    class SlidingWindowRateLimiter < RateLimiter
      def check_limit(key : String) : {allowed: Bool, count: Int32, reset_at: Time}
        now = Time.utc.to_unix.to_i64
        window_start = now - @window.total_seconds.to_i64
        
        # Clean up old entries and count current requests
        data = @store.get(key) || Hash(String, Int32 | Int64).new
        current_count = 0
        
        # Count requests in the current window
        data.each do |timestamp_str, count|
          next if timestamp_str == "last_cleanup"
          
          timestamp = timestamp_str.to_i64
          if timestamp >= window_start
            current_count += count.as(Int32)
          end
        end
        
        if current_count >= @limit
          reset_at = Time.utc + @window
          return {allowed: false, count: current_count, reset_at: reset_at}
        end
        
        # Add current request
        current_second = now
        @store.increment(key, current_second.to_s)
        
        # Cleanup old entries periodically
        if should_cleanup?(data)
          cleanup_old_entries(key, window_start)
        end
        
        reset_at = Time.utc + @window
        {allowed: true, count: current_count + 1, reset_at: reset_at}
      end
      
      def reset_limit(key : String)
        @store.delete(key)
      end
      
      private def should_cleanup?(data : Hash(String, Int32 | Int64)) : Bool
        last_cleanup = data["last_cleanup"]?.try(&.as(Int64)) || 0
        Time.utc.to_unix - last_cleanup > 60 # Cleanup every minute
      end
      
      private def cleanup_old_entries(key : String, window_start : Int64)
        data = @store.get(key) || Hash(String, Int32 | Int64).new
        clean_data = Hash(String, Int32 | Int64).new
        
        data.each do |timestamp_str, count|
          next if timestamp_str == "last_cleanup"
          
          timestamp = timestamp_str.to_i64
          if timestamp >= window_start
            clean_data[timestamp_str] = count
          end
        end
        
        clean_data["last_cleanup"] = Time.utc.to_unix
        @store.set(key, clean_data, @window * 2) # Keep data longer for sliding window
      end
    end
    
    # Token bucket rate limiter
    class TokenBucketRateLimiter < RateLimiter
      @refill_rate : Int32
      
      def initialize(store : RateLimitStore, @limit : Int32, window : Time::Span, @refill_rate : Int32? = nil)
        super(store, @limit, window)
        @refill_rate = @refill_rate || (@limit / window.total_seconds).ceil.to_i32
      end
      
      def check_limit(key : String) : {allowed: Bool, count: Int32, reset_at: Time}
        now = Time.utc.to_unix.to_i64
        data = @store.get(key) || Hash(String, Int32 | Int64).new
        
        last_refill = data["last_refill"]?.try(&.as(Int64)) || now
        tokens = data["tokens"]?.try(&.as(Int32)) || @limit
        
        # Calculate tokens to add based on time passed
        time_passed = now - last_refill
        tokens_to_add = (time_passed * @refill_rate / @window.total_seconds).to_i32
        tokens = Math.min(tokens + tokens_to_add, @limit)
        
        if tokens < 1
          next_refill = last_refill + (@window.total_seconds / @refill_rate).ceil.to_i64
          reset_at = Time.unix(next_refill)
          return {allowed: false, count: @limit - tokens, reset_at: reset_at}
        end
        
        # Consume one token
        tokens -= 1
        
        # Update store
        @store.set(key, {
          "tokens" => tokens,
          "last_refill" => now
        }, @window * 2)
        
        # Estimate when bucket will be full again
        seconds_to_full = (@limit - tokens) * (@window.total_seconds / @refill_rate)
        reset_at = Time.utc + seconds_to_full.seconds
        
        {allowed: true, count: @limit - tokens, reset_at: reset_at}
      end
      
      def reset_limit(key : String)
        @store.set(key, {"tokens" => @limit, "last_refill" => Time.utc.to_unix}, @window * 2)
      end
    end
    
    # Rate limiting middleware
    class RateLimitMiddleware < Middleware::Base
      @limiter : RateLimiter
      @key_generator : Proc(Http::Request, String)
      @skip_routes : Set(String)
      @custom_response : Proc(Http::Request, {allowed: Bool, count: Int32, reset_at: Time}, Http::Response)?
      @headers_enabled : Bool
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        store = MemoryRateLimitStore.new
        @limiter = FixedWindowRateLimiter.new(store, 100, 60.seconds)
        @skip_routes = Set(String).new
        @custom_response = nil
        @headers_enabled = true
        
        @key_generator = ->(request : Http::Request) { 
          extract_client_identifier(request) 
        }
      end
      
      def call(request) : Http::Response
        # Skip rate limiting for specified routes
        if @skip_routes.includes?(request.path)
          return @app.call(request)
        end
        
        # Generate rate limit key
        key = @key_generator.call(request)
        
        # Check rate limit
        result = @limiter.check_limit(key)
        
        # Process the request
        response = if result[:allowed]
          @app.call(request)
        else
          handle_rate_limit_exceeded(request, result)
        end
        
        # Add rate limit headers
        if @headers_enabled
          add_rate_limit_headers(response, result)
        end
        
        response
      end
      
      def skip_route(path : String)
        @skip_routes << path
      end
      
      def skip_routes(*paths : String)
        paths.each { |path| @skip_routes << path }
      end
      
      def reset_limit_for_key(key : String)
        @limiter.reset_limit(key)
      end
      
      def reset_limit_for_request(request : Http::Request)
        key = @key_generator.call(request)
        reset_limit_for_key(key)
      end
      
      private def extract_client_identifier(request : Http::Request) : String
        # Try to get real IP address
        if forwarded_for = request.headers["X-Forwarded-For"]?
          return forwarded_for.split(",").first.strip
        end
        
        if real_ip = request.headers["X-Real-IP"]?
          return real_ip
        end
        
        # Fallback to connection remote address
        "unknown_client"
      end
      
      private def handle_rate_limit_exceeded(request : Http::Request, 
                                           result : {allowed: Bool, count: Int32, reset_at: Time}) : Http::Response
        if custom_response = @custom_response
          return custom_response.call(request, result)
        end
        
        response = Http::Response.new(429, "")
        response.headers["Content-Type"] = "application/json"
        response.headers["Retry-After"] = (result[:reset_at] - Time.utc).total_seconds.ceil.to_i.to_s
        
        error_body = {
          error: "Rate limit exceeded",
          message: "Too many requests. Please try again later.",
          retry_after: result[:reset_at].to_rfc3339
        }
        
        response.body = error_body.to_json
        response
      end
      
      private def add_rate_limit_headers(response : Http::Response, 
                                       result : {allowed: Bool, count: Int32, reset_at: Time})
        response.headers["X-RateLimit-Remaining"] = (@limiter.@limit - result[:count]).to_s
        response.headers["X-RateLimit-Reset"] = result[:reset_at].to_unix.to_s
        response.headers["X-RateLimit-Reset-After"] = (result[:reset_at] - Time.utc).total_seconds.ceil.to_i.to_s
        
        unless result[:allowed]
          response.headers["Retry-After"] = (result[:reset_at] - Time.utc).total_seconds.ceil.to_i.to_s
        end
      end
    end
    
    # Rate limit configuration builder
    class RateLimitConfig
      @global_limits : Array({limiter: RateLimiter, key_generator: Proc(Http::Request, String)?})
      @path_limits : Hash(String, Array({limiter: RateLimiter, key_generator: Proc(Http::Request, String)?}))
      @store : RateLimitStore
      
      def initialize(@store : RateLimitStore? = nil)
        @store = @store || MemoryRateLimitStore.new
        @global_limits = [] of {limiter: RateLimiter, key_generator: Proc(Http::Request, String)?}
        @path_limits = Hash(String, Array({limiter: RateLimiter, key_generator: Proc(Http::Request, String)?})).new
      end
      
      def global_limit(requests : Int32, per : Time::Span, strategy : RateLimitStrategy = RateLimitStrategy::FixedWindow,
                      key_generator : Proc(Http::Request, String)? = nil)
        limiter = create_limiter(strategy, requests, per)
        @global_limits << {limiter: limiter, key_generator: key_generator}
        self
      end
      
      def path_limit(path : String, requests : Int32, per : Time::Span, 
                    strategy : RateLimitStrategy = RateLimitStrategy::FixedWindow,
                    key_generator : Proc(Http::Request, String)? = nil)
        limiter = create_limiter(strategy, requests, per)
        @path_limits[path] ||= [] of {limiter: RateLimiter, key_generator: Proc(Http::Request, String)?}
        @path_limits[path] << {limiter: limiter, key_generator: key_generator}
        self
      end
      
      def user_limit(requests : Int32, per : Time::Span, strategy : RateLimitStrategy = RateLimitStrategy::FixedWindow)
        key_generator = ->(request : Http::Request) {
          # Extract user ID from session, JWT, or other auth mechanism
          user_id = extract_user_id(request)
          "user:#{user_id}"
        }
        
        global_limit(requests, per, strategy, key_generator)
      end
      
      def api_key_limit(requests : Int32, per : Time::Span, strategy : RateLimitStrategy = RateLimitStrategy::FixedWindow)
        key_generator = ->(request : Http::Request) {
          # Extract API key from headers or query params
          api_key = request.headers["X-API-Key"]? || request.headers["Authorization"]?.try(&.gsub("Bearer ", ""))
          "api_key:#{api_key || "anonymous"}"
        }
        
        global_limit(requests, per, strategy, key_generator)
      end
      
      def build_middlewares : Array(RateLimitMiddleware)
        middlewares = [] of RateLimitMiddleware
        
        # Create global rate limit middlewares
        @global_limits.each do |config|
          middlewares << RateLimitMiddleware.new(
            limiter: config[:limiter],
            key_generator: config[:key_generator]
          )
        end
        
        # Create path-specific rate limit middlewares
        @path_limits.each do |path, configs|
          configs.each do |config|
            middleware = RateLimitMiddleware.new(
              limiter: config[:limiter],
              key_generator: config[:key_generator]
            )
            
            # Skip all routes except the specific path
            middleware.skip_routes("*")
            # Only apply to specific path (would need route matching logic)
            middlewares << middleware
          end
        end
        
        middlewares
      end
      
      private def create_limiter(strategy : RateLimitStrategy, requests : Int32, window : Time::Span) : RateLimiter
        case strategy
        when .fixed_window?
          FixedWindowRateLimiter.new(@store, requests, window)
        when .sliding_window?
          SlidingWindowRateLimiter.new(@store, requests, window)
        when .token_bucket?
          TokenBucketRateLimiter.new(@store, requests, window)
        else
          FixedWindowRateLimiter.new(@store, requests, window)
        end
      end
      
      private def extract_user_id(request : Http::Request) : String
        # This would integrate with your authentication system
        # For now, return a placeholder
        "anonymous"
      end
    end
  end
end