require "json"

module Amethyst
  module SSE
    # Server-Sent Events connection
    class Connection
      getter :id
      getter :response
      getter :path
      getter :params
      getter :headers
      property :user_data
      property :subscriptions
      property last_event_id : String?
      
      @response : Http::Response
      @io : IO
      @alive : Bool
      @retry_interval : Int32
      @heartbeat_interval : Time::Span
      @compression : Bool
      @cors_enabled : Bool
      @allowed_origins : Array(String)
      
      def initialize(@id : String, @response : Http::Response, @io : IO, @path : String,
                     @params : Hash(String, String) = {} of String => String,
                     @headers : ::HTTP::Headers = ::HTTP::Headers.new,
                     @retry_interval : Int32 = 3000,
                     @heartbeat_interval : Time::Span = 30.seconds,
                     @compression : Bool = false,
                     @cors_enabled : Bool = true,
                     @allowed_origins : Array(String) = ["*"])
        @alive = true
        @user_data = {} of String => String
        @subscriptions = Set(String).new
        @last_event_id = nil
        
        setup_sse_headers
        start_heartbeat
      end
      
      def send_event(data : String, event : String? = nil, id : String? = nil, retry : Int32? = nil)
        return unless @alive
        
        begin
          if id
            @io.print("id: #{id}\n")
          end
          
          if event
            @io.print("event: #{event}\n")
          end
          
          if retry
            @io.print("retry: #{retry}\n")
          end
          
          # Handle multi-line data
          data.split('\n').each do |line|
            @io.print("data: #{line}\n")
          end
          
          @io.print("\n")
          @io.flush
          
        rescue ex
          Base::App.logger.log_string "SSE send error: #{ex.message}"
          close
        end
      end
      
      def send_json(data : Hash | Array, event : String? = nil, id : String? = nil)
        json_data = data.to_json
        send_event(json_data, event, id)
      end
      
      def send_heartbeat
        send_event(": heartbeat", nil, nil)
      end
      
      def close
        return unless @alive
        @alive = false
        
        begin
          @io.close
        rescue ex
          Base::App.logger.log_string "SSE close error: #{ex.message}"
        end
        
        ConnectionManager.instance.remove_connection(@id)
      end
      
      def closed?
        !@alive
      end
      
      def subscribe(channel : String)
        @subscriptions << channel
        ConnectionManager.instance.subscribe(self, channel)
      end
      
      def unsubscribe(channel : String)
        @subscriptions.delete(channel)
        ConnectionManager.instance.unsubscribe(self, channel)
      end
      
      def set_retry_interval(milliseconds : Int32)
        @retry_interval = milliseconds
        send_event("", nil, nil, @retry_interval)
      end
      
      private def setup_sse_headers
        @response.headers["Content-Type"] = "text/event-stream"
        @response.headers["Cache-Control"] = "no-cache"
        @response.headers["Connection"] = "keep-alive"
        @response.headers["X-Accel-Buffering"] = "no" # Disable nginx buffering
        
        if @compression
          @response.headers["Content-Encoding"] = "gzip"
        end
        
        if @cors_enabled
          origin = @headers["Origin"]?
          if origin && (@allowed_origins.includes?("*") || @allowed_origins.includes?(origin))
            @response.headers["Access-Control-Allow-Origin"] = origin
            @response.headers["Access-Control-Allow-Credentials"] = "true"
            @response.headers["Access-Control-Expose-Headers"] = "Content-Type"
          end
        end
        
        # Send initial retry interval
        @io.print("retry: #{@retry_interval}\n\n")
        @io.flush
      end
      
      private def start_heartbeat
        spawn do
          while @alive
            sleep @heartbeat_interval
            next unless @alive
            
            send_heartbeat
          end
        end
      end
    end
    
    # Server-Sent Events message structure
    struct Event
      include JSON::Serializable
      
      property data : JSON::Any
      property event : String?
      property id : String?
      property retry : Int32?
      property timestamp : Int64
      
      def initialize(@data : JSON::Any, @event : String? = nil, @id : String? = nil, @retry : Int32? = nil)
        @timestamp = Time.utc.to_unix
      end
      
      def self.create(data : Hash(String, String) | Array(String) | String | Number | Bool, event : String? = nil, id : String? = nil)
        new(JSON.parse(data.to_json), event, id)
      end
    end
    
    # Connection manager for SSE connections
    class ConnectionManager
      @@instance : ConnectionManager?
      
      @connections : Hash(String, Connection)
      @channels : Hash(String, Set(Connection))
      @event_history : Hash(String, Array(Event))
      @history_size_limit : Int32
      @mutex : Mutex
      
      def initialize(@history_size_limit : Int32 = 100)
        @connections = Hash(String, Connection).new
        @channels = Hash(String, Set(Connection)).new
        @event_history = Hash(String, Array(Event)).new
        @mutex = Mutex.new
      end
      
      def self.instance
        @@instance ||= new
      end
      
      def add_connection(connection : Connection)
        @mutex.synchronize do
          @connections[connection.id] = connection
        end
        
        Base::App.logger.log_string "SSE connection added: #{connection.id}"
      end
      
      def remove_connection(connection_id : String)
        @mutex.synchronize do
          if connection = @connections.delete(connection_id)
            # Remove from all channels
            @channels.each do |channel, connections|
              connections.delete(connection)
            end
          end
        end
        
        Base::App.logger.log_string "SSE connection removed: #{connection_id}"
      end
      
      def get_connection(connection_id : String) : Connection?
        @connections[connection_id]?
      end
      
      def subscribe(connection : Connection, channel : String)
        @mutex.synchronize do
          @channels[channel] ||= Set(Connection).new
          @channels[channel] << connection
          
          # Send recent events from history if available
          send_channel_history(connection, channel)
        end
        
        Base::App.logger.log_string "SSE connection #{connection.id} subscribed to #{channel}"
      end
      
      def unsubscribe(connection : Connection, channel : String)
        @mutex.synchronize do
          @channels[channel]?.try(&.delete(connection))
        end
        
        Base::App.logger.log_string "SSE connection #{connection.id} unsubscribed from #{channel}"
      end
      
      def broadcast_to_channel(channel : String, data : Hash(String, String) | Array(String) | String, 
                              event : String? = nil, id : String? = nil)
        event_obj = Event.create(data, event, id)
        
        @mutex.synchronize do
          # Store in history
          @event_history[channel] ||= Array(Event).new
          @event_history[channel] << event_obj
          
          # Limit history size
          if @event_history[channel].size > @history_size_limit
            @event_history[channel].shift
          end
          
          # Broadcast to subscribed connections
          connections = @channels[channel]?
          return unless connections
          
          connections.each do |connection|
            next if connection.closed?
            
            if data.is_a?(String)
              connection.send_event(data, event, id)
            else
              connection.send_json(data, event, id)
            end
          end
        end
      end
      
      def broadcast_to_all(data : Hash(String, String) | Array(String) | String, event : String? = nil, id : String? = nil)
        @connections.each_value do |connection|
          next if connection.closed?
          
          if data.is_a?(String)
            connection.send_event(data, event, id)
          else
            connection.send_json(data, event, id)
          end
        end
      end
      
      def get_channel_history(channel : String, since_id : String? = nil) : Array(Event)
        @mutex.synchronize do
          history = @event_history[channel]? || [] of Event
          
          return history unless since_id
          
          # Find events after the specified ID
          since_index = history.index { |event| event.id == since_id }
          return history unless since_index
          
          history[(since_index + 1)..-1]
        end
      end
      
      def stats
        @mutex.synchronize do
          {
            total_connections: @connections.size,
            active_connections: @connections.count { |_, conn| !conn.closed? },
            channels: @channels.size,
            subscriptions: @channels.sum { |_, conns| conns.size },
            history_size: @event_history.sum { |_, events| events.size }
          }
        end
      end
      
      def cleanup_closed_connections
        closed_connections = [] of String
        
        @connections.each do |id, connection|
          if connection.closed?
            closed_connections << id
          end
        end
        
        closed_connections.each do |id|
          remove_connection(id)
        end
        
        closed_connections.size
      end
      
      private def send_channel_history(connection : Connection, channel : String)
        history = @event_history[channel]?
        return unless history
        
        last_event_id = connection.last_event_id
        events_to_send = if last_event_id
          get_channel_history(channel, last_event_id)
        else
          history.last(10) # Send last 10 events for new connections
        end
        
        events_to_send.each do |event|
          if event.data.as_h?
            connection.send_json(event.data.as_h, event.event, event.id)
          else
            connection.send_event(event.data.to_s, event.event, event.id)
          end
        end
      end
    end
    
    # SSE controller base class
    abstract class Controller
      getter :connection
      
      def initialize(@connection : Connection)
      end
      
      abstract def on_connect
      abstract def on_disconnect
      
      def send_event(data : String, event : String? = nil, id : String? = nil)
        @connection.send_event(data, event, id)
      end
      
      def send_json(data : Hash | Array, event : String? = nil, id : String? = nil)
        @connection.send_json(data, event, id)
      end
      
      def subscribe(channel : String)
        @connection.subscribe(channel)
      end
      
      def unsubscribe(channel : String)
        @connection.unsubscribe(channel)
      end
      
      def broadcast_to_channel(channel : String, data : Hash(String, String) | Array(String) | String, 
                              event : String? = nil, id : String? = nil)
        ConnectionManager.instance.broadcast_to_channel(channel, data, event, id)
      end
      
      def broadcast_to_all(data : Hash(String, String) | Array(String) | String, event : String? = nil, id : String? = nil)
        ConnectionManager.instance.broadcast_to_all(data, event, id)
      end
      
      def set_retry_interval(milliseconds : Int32)
        @connection.set_retry_interval(milliseconds)
      end
    end
    
    # SSE middleware for handling EventSource connections
    class SSEHandler < Middleware::Base
      @sse_routes : Hash(String, Proc(Connection, Nil))
      @controller_classes : Hash(String, Controller.class)
      
      def initialize(@app = self)
        @sse_routes = Hash(String, Proc(Connection, Nil)).new
        @controller_classes = Hash(String, Controller.class).new
      end
      
      def call(request) : Http::Response
        if sse_request?(request)
          handle_sse_connection(request)
        else
          @app.call(request)
        end
      end
      
      def add_sse_route(path : String, controller_class : Controller.class)
        @controller_classes[path] = controller_class
        
        @sse_routes[path] = ->(connection : Connection) do
          controller = controller_class.new(connection)
          controller.on_connect
        end
      end
      
      def add_sse_route(path : String, &handler : Connection -> Nil)
        @sse_routes[path] = handler
      end
      
      private def sse_request?(request : Http::Request) : Bool
        accept_header = request.headers["Accept"]?
        accept_header.try(&.includes?("text/event-stream")) || false
      end
      
      private def handle_sse_connection(request : Http::Request) : Http::Response
        path = request.path
        
        # Find matching SSE route
        handler = @sse_routes[path]?
        unless handler
          return Http::Response.new(404, "SSE endpoint not found")
        end
        
        # Create streaming response
        response = Http::Response.new(200, "")
        
        # Start SSE handling in a fiber
        spawn do
          begin
            # Create a custom IO that writes directly to the response
            io = create_response_io(response)
            
            connection_id = UUID.random.to_s
            connection = Connection.new(
              id: connection_id,
              response: response,
              io: io,
              path: path,
              params: extract_params(request.query || ""),
              headers: request.headers
            )
            
            # Extract Last-Event-ID for reconnection
            if last_event_id = request.headers["Last-Event-ID"]?
              connection.last_event_id = last_event_id
            end
            
            ConnectionManager.instance.add_connection(connection)
            handler.call(connection)
            
            # Keep connection alive until client disconnects
            while !connection.closed?
              sleep 1.second
            end
            
          rescue ex
            Base::App.logger.log_string "SSE error: #{ex.message}"
          end
        end
        
        response
      end
      
      private def create_response_io(response : Http::Response) : IO
        # This is a simplified implementation
        # In practice, you'd need to create an IO that writes to the HTTP response stream
        STDOUT # Placeholder - replace with actual response stream
      end
      
      private def extract_params(query : String) : Hash(String, String)
        params = {} of String => String
        
        query.split("&").each do |pair|
          if pair.includes?("=")
            key, value = pair.split("=", 2)
            params[URI.decode_www_form(key)] = URI.decode_www_form(value)
          end
        end
        
        params
      end
    end
    
    # Helper class for creating SSE streams
    class Stream
      @connections : Set(Connection)
      @channel : String
      
      def initialize(@channel : String)
        @connections = Set(Connection).new
      end
      
      def add_connection(connection : Connection)
        @connections << connection
        connection.subscribe(@channel)
      end
      
      def remove_connection(connection : Connection)
        @connections.delete(connection)
        connection.unsubscribe(@channel)
      end
      
      def broadcast(data : Hash(String, String) | Array(String) | String, event : String? = nil, id : String? = nil)
        ConnectionManager.instance.broadcast_to_channel(@channel, data, event, id)
      end
      
      def size
        @connections.size
      end
      
      def active_connections
        @connections.count { |conn| !conn.closed? }
      end
    end
  end
end