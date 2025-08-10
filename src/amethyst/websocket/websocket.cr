require "http/web_socket"
require "json"

module Amethyst
  module WebSocket
    # WebSocket connection wrapper
    class Connection
      getter :id
      getter :socket
      getter :path
      getter :params
      getter :headers
      property :user_data
      property :subscriptions
      
      @socket : ::HTTP::WebSocket
      @alive : Bool
      @last_pong : Time
      @ping_interval : Time::Span
      @timeout : Time::Span
      @message_handlers : Hash(String, Proc(Message, Nil))
      @close_handlers : Array(Proc(Connection, Nil))
      
      def initialize(@id : String, @socket : ::HTTP::WebSocket, @path : String, 
                     @params : Hash(String, String) = {} of String => String,
                     @headers : ::HTTP::Headers = ::HTTP::Headers.new,
                     @ping_interval : Time::Span = 30.seconds,
                     @timeout : Time::Span = 60.seconds)
        @alive = true
        @last_pong = Time.utc
        @user_data = {} of String => String
        @subscriptions = Set(String).new
        @message_handlers = Hash(String, Proc(Message, Nil)).new
        @close_handlers = Array(Proc(Connection, Nil)).new
        
        setup_socket_handlers
        start_ping_loop
      end
      
      def send(message : String)
        return unless @alive
        @socket.send(message)
      rescue ex
        Base::App.logger.log_string "WebSocket send error: #{ex.message}"
        close
      end
      
      def send(data : Hash | Array)
        send(data.to_json)
      end
      
      def send_binary(data : Bytes)
        return unless @alive
        @socket.send(data)
      rescue ex
        Base::App.logger.log_string "WebSocket binary send error: #{ex.message}"
        close
      end
      
      def close(code : ::HTTP::WebSocket::CloseCode = ::HTTP::WebSocket::CloseCode::NormalClosure, 
                reason : String = "")
        return unless @alive
        
        @alive = false
        @socket.close(code, reason)
        @close_handlers.each(&.call(self))
      rescue ex
        Base::App.logger.log_string "WebSocket close error: #{ex.message}"
      end
      
      def closed?
        !@alive || @socket.closed?
      end
      
      def subscribe(channel : String)
        @subscriptions << channel
        ConnectionManager.instance.subscribe(self, channel)
      end
      
      def unsubscribe(channel : String)
        @subscriptions.delete(channel)
        ConnectionManager.instance.unsubscribe(self, channel)
      end
      
      def on_message(event_type : String, &handler : Message -> Nil)
        @message_handlers[event_type] = handler
      end
      
      def on_close(&handler : Connection -> Nil)
        @close_handlers << handler
      end
      
      def ping
        return unless @alive
        @socket.ping("ping")
      rescue ex
        Base::App.logger.log_string "WebSocket ping error: #{ex.message}"
        close
      end
      
      private def setup_socket_handlers
        @socket.on_message do |message|
          handle_message(message)
        end
        
        @socket.on_binary do |data|
          handle_binary_message(data)
        end
        
        @socket.on_close do |code, reason|
          @alive = false
          @close_handlers.each(&.call(self))
        end
        
        @socket.on_ping do |data|
          @socket.pong(data)
        end
        
        @socket.on_pong do |data|
          @last_pong = Time.utc
        end
      end
      
      private def handle_message(raw_message : String)
        begin
          data = JSON.parse(raw_message)
          message = Message.from_json(data)
          
          # Handle built-in message types
          case message.type
          when "subscribe"
            if channel = message.data["channel"]?.try(&.as_s)
              subscribe(channel)
              send({type: "subscribed", channel: channel})
            end
          when "unsubscribe"
            if channel = message.data["channel"]?.try(&.as_s)
              unsubscribe(channel)
              send({type: "unsubscribed", channel: channel})
            end
          else
            # Handle custom message types
            if handler = @message_handlers[message.type]?
              handler.call(message)
            end
          end
        rescue ex
          Base::App.logger.log_string "WebSocket message parse error: #{ex.message}"
          send({type: "error", message: "Invalid message format"})
        end
      end
      
      private def handle_binary_message(data : Bytes)
        # Handle binary messages - can be overridden by subclasses
      end
      
      private def start_ping_loop
        spawn do
          while @alive
            sleep @ping_interval
            
            if Time.utc - @last_pong > @timeout
              Base::App.logger.log_string "WebSocket timeout for connection #{@id}"
              close(::HTTP::WebSocket::CloseCode::GoingAway, "Timeout")
              break
            end
            
            ping
          end
        end
      end
    end
    
    # WebSocket message structure
    struct Message
      include JSON::Serializable
      
      property type : String
      property data : JSON::Any
      property timestamp : Int64
      property id : String?
      
      def initialize(@type : String, @data : JSON::Any, @id : String? = nil)
        @timestamp = Time.utc.to_unix
      end
      
      def self.create(type : String, data : Hash | Array | String | Number | Bool)
        new(type, JSON.parse(data.to_json))
      end
    end
    
    # Connection manager for broadcasting and subscriptions
    class ConnectionManager
      @@instance : ConnectionManager?
      
      @connections : Hash(String, Connection)
      @channels : Hash(String, Set(Connection))
      @mutex : Mutex
      
      def initialize
        @connections = Hash(String, Connection).new
        @channels = Hash(String, Set(Connection)).new
        @mutex = Mutex.new
      end
      
      def self.instance
        @@instance ||= new
      end
      
      def add_connection(connection : Connection)
        @mutex.synchronize do
          @connections[connection.id] = connection
          
          connection.on_close do |conn|
            remove_connection(conn.id)
          end
        end
        
        Base::App.logger.log_string "WebSocket connection added: #{connection.id}"
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
        
        Base::App.logger.log_string "WebSocket connection removed: #{connection_id}"
      end
      
      def get_connection(connection_id : String) : Connection?
        @connections[connection_id]?
      end
      
      def subscribe(connection : Connection, channel : String)
        @mutex.synchronize do
          @channels[channel] ||= Set(Connection).new
          @channels[channel] << connection
        end
        
        Base::App.logger.log_string "Connection #{connection.id} subscribed to #{channel}"
      end
      
      def unsubscribe(connection : Connection, channel : String)
        @mutex.synchronize do
          @channels[channel]?.try(&.delete(connection))
        end
        
        Base::App.logger.log_string "Connection #{connection.id} unsubscribed from #{channel}"
      end
      
      def broadcast_to_channel(channel : String, message : Hash(String, String) | Array(String) | String)
        @mutex.synchronize do
          connections = @channels[channel]?
          return unless connections
          
          json_message = message.is_a?(String) ? message : message.to_json
          
          connections.each do |connection|
            next if connection.closed?
            connection.send(json_message)
          end
        end
      end
      
      def broadcast_to_all(message : Hash(String, String) | Array(String) | String)
        json_message = message.is_a?(String) ? message : message.to_json
        
        @connections.each_value do |connection|
          next if connection.closed?
          connection.send(json_message)
        end
      end
      
      def stats
        @mutex.synchronize do
          {
            total_connections: @connections.size,
            active_connections: @connections.count { |_, conn| !conn.closed? },
            channels: @channels.size,
            subscriptions: @channels.sum { |_, conns| conns.size }
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
      
      def get_channel_connections(channel : String) : Array(Connection)
        @channels[channel]?.try(&.to_a) || [] of Connection
      end
      
      def get_connection_channels(connection : Connection) : Array(String)
        channels = [] of String
        
        @channels.each do |channel, connections|
          if connections.includes?(connection)
            channels << channel
          end
        end
        
        channels
      end
    end
    
    # WebSocket controller base class
    abstract class Controller
      getter :connection
      
      def initialize(@connection : Connection)
        setup_message_handlers
      end
      
      abstract def on_connect
      abstract def on_disconnect
      
      def on_message(type : String, data : JSON::Any)
        # Override in subclasses to handle custom message types
      end
      
      def send(message : Hash(String, String) | Array(String) | String)
        @connection.send(message)
      end
      
      def subscribe(channel : String)
        @connection.subscribe(channel)
      end
      
      def unsubscribe(channel : String)
        @connection.unsubscribe(channel)
      end
      
      def broadcast_to_channel(channel : String, message : Hash(String, String) | Array(String) | String)
        ConnectionManager.instance.broadcast_to_channel(channel, message)
      end
      
      def broadcast_to_all(message : Hash(String, String) | Array(String) | String)
        ConnectionManager.instance.broadcast_to_all(message)
      end
      
      private def setup_message_handlers
        @connection.on_message("*") do |message|
          on_message(message.type, message.data)
        end
        
        @connection.on_close do |conn|
          on_disconnect
        end
      end
    end
    
    # WebSocket middleware for handling upgrades
    class WebSocketHandler < Middleware::Base
      @websocket_routes : Hash(String, Proc(Connection, Nil))
      @controller_classes : Hash(String, Controller.class)
      
      def initialize(@app = self)
        @websocket_routes = Hash(String, Proc(Connection, Nil)).new
        @controller_classes = Hash(String, Controller.class).new
      end
      
      def call(request) : Http::Response
        if websocket_request?(request)
          handle_websocket_upgrade(request)
        else
          @app.call(request)
        end
      end
      
      def add_websocket_route(path : String, controller_class : Controller.class)
        @controller_classes[path] = controller_class
        
        @websocket_routes[path] = ->(connection : Connection) do
          controller = controller_class.new(connection)
          controller.on_connect
        end
      end
      
      def add_websocket_route(path : String, &handler : Connection -> Nil)
        @websocket_routes[path] = handler
      end
      
      private def websocket_request?(request : Http::Request) : Bool
        connection_header = request.headers["Connection"]?
        upgrade_header = request.headers["Upgrade"]?
        
        connection_header.try(&.downcase.includes?("upgrade")) &&
        upgrade_header.try(&.downcase) == "websocket"
      end
      
      private def handle_websocket_upgrade(request : Http::Request) : Http::Response
        path = request.path
        
        # Find matching WebSocket route
        handler = @websocket_routes[path]?
        unless handler
          return Http::Response.new(404, "WebSocket endpoint not found")
        end
        
        # Validate WebSocket headers
        unless validate_websocket_headers(request)
          return Http::Response.new(400, "Invalid WebSocket request")
        end
        
        # Create WebSocket connection
        websocket_key = request.headers["Sec-WebSocket-Key"]
        accept_key = ::HTTP::WebSocket.key_challenge(websocket_key)
        
        response = Http::Response.new(101, "")
        response.headers["Upgrade"] = "websocket"
        response.headers["Connection"] = "Upgrade"
        response.headers["Sec-WebSocket-Accept"] = accept_key
        
        # Extract protocols if present
        if protocols = request.headers["Sec-WebSocket-Protocol"]?
          response.headers["Sec-WebSocket-Protocol"] = protocols.split(",").first.strip
        end
        
        # Start WebSocket handling in a fiber
        spawn do
          begin
            socket = ::HTTP::WebSocket.new(request.socket, request.headers)
            connection_id = UUID.random.to_s
            connection = Connection.new(
              id: connection_id,
              socket: socket,
              path: path,
              params: extract_params(path, request.query || ""),
              headers: request.headers
            )
            
            ConnectionManager.instance.add_connection(connection)
            handler.call(connection)
            socket.run
            
          rescue ex
            Base::App.logger.log_string "WebSocket error: #{ex.message}"
          end
        end
        
        response
      end
      
      private def validate_websocket_headers(request : Http::Request) : Bool
        required_headers = ["Sec-WebSocket-Key", "Sec-WebSocket-Version"]
        
        required_headers.all? do |header|
          request.headers[header]?
        end
      end
      
      private def extract_params(path : String, query : String) : Hash(String, String)
        params = {} of String => String
        
        # Parse query parameters
        query.split("&").each do |pair|
          if pair.includes?("=")
            key, value = pair.split("=", 2)
            params[URI.decode_www_form(key)] = URI.decode_www_form(value)
          end
        end
        
        params
      end
    end
  end
end