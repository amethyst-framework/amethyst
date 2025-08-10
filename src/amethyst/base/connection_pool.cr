module Amethyst
  module Base
    class ConnectionPool(T)
      @pool : Channel(T)
      @factory : -> T
      @cleanup : T -> Nil
      @max_size : Int32
      @current_size : Atomic(Int32)
      @created_count : Atomic(Int64)
      @borrowed_count : Atomic(Int64)
      @returned_count : Atomic(Int64)
      @timeout : Time::Span
      @health_check : T -> Bool
      
      def initialize(factory : -> T,
                     @max_size : Int32 = 25, 
                     @timeout : Time::Span = 5.seconds,
                     @cleanup : T -> Nil = ->(connection : T) {},
                     @health_check : T -> Bool = ->(connection : T) { true })
        @factory = factory
        @pool = Channel(T).new(@max_size)
        @current_size = Atomic(Int32).new(0)
        @created_count = Atomic(Int64).new(0)
        @borrowed_count = Atomic(Int64).new(0)
        @returned_count = Atomic(Int64).new(0)
      end
      
      def borrow(&block : T -> R) forall R
        connection = borrow_connection
        begin
          yield connection
        ensure
          return_connection(connection)
        end
      end
      
      def borrow_connection : T
        @borrowed_count.add(1)
        
        # Try to get from pool first
        select
        when connection = @pool.receive?
          # Validate connection health
          if @health_check.call(connection)
            return connection
          else
            # Connection is unhealthy, create a new one
            @current_size.sub(1)
            @cleanup.call(connection)
          end
        when timeout(@timeout)
          # Pool is empty or timeout reached
        end
        
        # Create new connection if under limit
        current = @current_size.get
        if current < @max_size
          if @current_size.compare_and_set(current, current + 1)
            connection = @factory.call
            @created_count.add(1)
            return connection
          end
        end
        
        # Wait for available connection
        select
        when connection = @pool.receive
          if @health_check.call(connection)
            return connection
          else
            @current_size.sub(1)
            @cleanup.call(connection)
            # Recursively try again
            return borrow_connection
          end
        when timeout(@timeout)
          raise Exception.new("Connection pool timeout after #{@timeout}")
        end
      end
      
      def return_connection(connection : T)
        @returned_count.add(1)
        
        # Validate connection before returning to pool
        if @health_check.call(connection)
          select
          when @pool.send(connection)
            # Successfully returned to pool
          else
            # Pool is full, cleanup connection
            @current_size.sub(1)
            @cleanup.call(connection)
          end
        else
          # Connection is unhealthy, cleanup and decrement count
          @current_size.sub(1)
          @cleanup.call(connection)
        end
      end
      
      def size : Int32
        @current_size.get
      end
      
      def available : Int32
        @pool.size
      end
      
      def stats
        {
          max_size: @max_size,
          current_size: @current_size.get,
          available: @pool.size,
          created_count: @created_count.get,
          borrowed_count: @borrowed_count.get,
          returned_count: @returned_count.get,
          timeout: @timeout.total_seconds
        }
      end
      
      def close
        while connection = @pool.receive?
          @cleanup.call(connection)
        end
        @current_size.set(0)
      end
      
      def clear
        close
      end
      
      # Preload pool with initial connections
      def preload(count : Int32)
        count.times do
          break if @current_size.get >= @max_size
          
          if @current_size.compare_and_set(@current_size.get, @current_size.get + 1)
            connection = @factory.call
            @created_count.add(1)
            @pool.send(connection)
          end
        end
      end
      
      # Health check all connections in pool
      def health_check_all
        unhealthy_count = 0
        temp_connections = [] of T
        
        # Remove all connections from pool
        while connection = @pool.receive?
          if @health_check.call(connection)
            temp_connections << connection
          else
            @cleanup.call(connection)
            @current_size.sub(1)
            unhealthy_count += 1
          end
        end
        
        # Return healthy connections back to pool
        temp_connections.each do |connection|
          @pool.send(connection)
        end
        
        unhealthy_count
      end
    end
    
    # Specialized connection pool for HTTP connections
    class HttpConnectionPool
      @pools : Hash(String, ConnectionPool(::HTTP::Client))
      @default_pool_size : Int32
      @connection_timeout : Time::Span
      
      def initialize(@default_pool_size : Int32 = 10, @connection_timeout : Time::Span = 5.seconds)
        @pools = Hash(String, ConnectionPool(::HTTP::Client)).new
      end
      
      def get_pool(host : String, port : Int32, ssl : Bool = false) : ConnectionPool(::HTTP::Client)
        key = "#{ssl ? "https" : "http"}://#{host}:#{port}"
        
        @pools[key] ||= ConnectionPool(::HTTP::Client).new(
          max_size: @default_pool_size,
          timeout: @connection_timeout,
          factory: -> { create_client(host, port, ssl) },
          cleanup: ->(client : ::HTTP::Client) { client.close rescue nil },
          health_check: ->(client : ::HTTP::Client) { !client.closed? }
        )
      end
      
      def request(method : String, url : String, headers = nil, body = nil, &block : ::HTTP::Client::Response -> T) forall T
        uri = URI.parse(url)
        host = uri.host || "localhost"
        port = uri.port || (uri.scheme == "https" ? 443 : 80)
        ssl = uri.scheme == "https"
        
        pool = get_pool(host, port, ssl)
        
        pool.borrow do |client|
          response = client.exec(method.upcase, uri.full_path, headers, body)
          yield response
        end
      end
      
      def get(url : String, headers = nil, &block : ::HTTP::Client::Response -> T) forall T
        request("GET", url, headers, nil, &block)
      end
      
      def post(url : String, headers = nil, body = nil, &block : ::HTTP::Client::Response -> T) forall T
        request("POST", url, headers, body, &block)
      end
      
      def stats
        @pools.transform_values(&.stats)
      end
      
      def close_all
        @pools.each_value(&.close)
        @pools.clear
      end
      
      private def create_client(host : String, port : Int32, ssl : Bool) : ::HTTP::Client
        client = ::HTTP::Client.new(host, port, ssl)
        client.connect_timeout = @connection_timeout
        client.read_timeout = @connection_timeout * 2
        client
      end
    end
  end
end