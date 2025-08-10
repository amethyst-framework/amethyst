module Amethyst
  module Http
    class Http2Server
      @handler : Proc(Http::Request, Http::Response) | Middleware::Base
      @connection_pool : Base::ConnectionPool(HTTP2Connection)
      @settings : Hash(Symbol, UInt32)
      
      struct HTTP2Connection
        getter socket : TCPSocket
        getter streams : Hash(UInt32, HTTP2Stream)
        getter settings : Hash(Symbol, UInt32)
        property last_stream_id : UInt32
        
        def initialize(@socket : TCPSocket)
          @streams = Hash(UInt32, HTTP2Stream).new
          @settings = {
            :header_table_size => 4096_u32,
            :enable_push => 1_u32,
            :max_concurrent_streams => 100_u32,
            :initial_window_size => 65535_u32,
            :max_frame_size => 16384_u32,
            :max_header_list_size => 8192_u32
          }
          @last_stream_id = 0_u32
        end
        
        def closed?
          @socket.closed?
        end
        
        def close
          @socket.close unless @socket.closed?
        end
      end
      
      struct HTTP2Stream
        property id : UInt32
        property state : Symbol
        property headers : Hash(String, String)
        property data : IO::Memory
        property window_size : Int32
        
        def initialize(@id : UInt32)
          @state = :idle
          @headers = Hash(String, String).new
          @data = IO::Memory.new
          @window_size = 65535
        end
      end
      
      struct HTTP2Frame
        property type : UInt8
        property flags : UInt8
        property stream_id : UInt32
        property payload : Bytes
        
        def initialize(@type : UInt8, @flags : UInt8, @stream_id : UInt32, @payload : Bytes)
        end
        
        def self.parse(data : Bytes) : HTTP2Frame?
          return nil if data.size < 9
          
          length = (data[0].to_u32 << 16) | (data[1].to_u32 << 8) | data[2].to_u32
          type = data[3]
          flags = data[4]
          stream_id = ((data[5].to_u32 & 0x7f) << 24) | (data[6].to_u32 << 16) | (data[7].to_u32 << 8) | data[8].to_u32
          
          return nil if data.size < 9 + length
          
          payload = data[9, length]
          HTTP2Frame.new(type, flags, stream_id, payload)
        end
        
        def to_bytes : Bytes
          frame_data = Bytes.new(9 + @payload.size)
          
          # Length (24 bits)
          frame_data[0] = (@payload.size >> 16).to_u8
          frame_data[1] = (@payload.size >> 8).to_u8
          frame_data[2] = @payload.size.to_u8
          
          # Type and flags
          frame_data[3] = @type
          frame_data[4] = @flags
          
          # Stream ID (31 bits)
          frame_data[5] = (@stream_id >> 24).to_u8
          frame_data[6] = (@stream_id >> 16).to_u8
          frame_data[7] = (@stream_id >> 8).to_u8
          frame_data[8] = @stream_id.to_u8
          
          # Payload
          @payload.copy_to(frame_data[9, @payload.size])
          
          frame_data
        end
      end
      
      def initialize(@handler : Proc(Http::Request, Http::Response) | Middleware::Base)
        @settings = {
          :header_table_size => 4096_u32,
          :enable_push => 0_u32,  # Disable server push by default
          :max_concurrent_streams => 100_u32,
          :initial_window_size => 65535_u32,
          :max_frame_size => 16384_u32,
          :max_header_list_size => 8192_u32
        }
        
        @connection_pool = Base::ConnectionPool(HTTP2Connection).new(
          max_size: 1000,
          factory: -> { raise "HTTP2 connections are created externally" },
          cleanup: ->(conn : HTTP2Connection) { conn.close },
          health_check: ->(conn : HTTP2Connection) { !conn.closed? }
        )
      end
      
      def handle_connection(socket : TCPSocket)
        connection = HTTP2Connection.new(socket)
        
        # Send connection preface
        send_connection_preface(connection)
        
        # Handle frames
        loop do
          break if connection.closed?
          
          frame_data = read_frame(connection.socket)
          break unless frame_data
          
          frame = HTTP2Frame.parse(frame_data)
          next unless frame
          
          handle_frame(connection, frame)
        rescue ex
          Base::App.logger.log_string "HTTP/2 connection error: #{ex.message}"
          break
        end
        
        connection.close
      end
      
      private def send_connection_preface(connection : HTTP2Connection)
        # Send SETTINGS frame
        settings_payload = encode_settings(@settings)
        settings_frame = HTTP2Frame.new(0x04_u8, 0x00_u8, 0_u32, settings_payload)
        connection.socket.write(settings_frame.to_bytes)
        
        # Send WINDOW_UPDATE frame for connection
        window_update = Bytes.new(4)
        window_update[0] = 0_u8
        window_update[1] = 0x01_u8
        window_update[2] = 0x00_u8  
        window_update[3] = 0x00_u8
        
        window_frame = HTTP2Frame.new(0x08_u8, 0x00_u8, 0_u32, window_update)
        connection.socket.write(window_frame.to_bytes)
      end
      
      private def handle_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        case frame.type
        when 0x00 # DATA
          handle_data_frame(connection, frame)
        when 0x01 # HEADERS
          handle_headers_frame(connection, frame)
        when 0x02 # PRIORITY
          handle_priority_frame(connection, frame)
        when 0x03 # RST_STREAM  
          handle_rst_stream_frame(connection, frame)
        when 0x04 # SETTINGS
          handle_settings_frame(connection, frame)
        when 0x05 # PUSH_PROMISE
          # Not implemented for server
        when 0x06 # PING
          handle_ping_frame(connection, frame)
        when 0x07 # GOAWAY
          handle_goaway_frame(connection, frame)
        when 0x08 # WINDOW_UPDATE
          handle_window_update_frame(connection, frame)
        else
          # Unknown frame type, ignore
        end
      end
      
      private def handle_headers_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        stream_id = frame.stream_id
        return if stream_id == 0
        
        stream = connection.streams[stream_id] ||= HTTP2Stream.new(stream_id)
        stream.state = :open
        
        # Decode headers (simplified HPACK decoding)
        headers = decode_headers(frame.payload)
        stream.headers.merge!(headers)
        
        # If END_HEADERS flag is set and this is a request
        if (frame.flags & 0x04) != 0
          process_request(connection, stream)
        end
      end
      
      private def handle_data_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        stream_id = frame.stream_id
        return if stream_id == 0
        
        stream = connection.streams[stream_id]?
        return unless stream
        
        stream.data.write(frame.payload)
        
        # If END_STREAM flag is set, process the complete request
        if (frame.flags & 0x01) != 0
          stream.state = :half_closed_remote
          process_request(connection, stream)
        end
      end
      
      private def handle_settings_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        if (frame.flags & 0x01) != 0  # ACK flag
          return
        end
        
        # Parse settings
        settings = decode_settings(frame.payload)
        connection.settings.merge!(settings)
        
        # Send SETTINGS ACK
        ack_frame = HTTP2Frame.new(0x04_u8, 0x01_u8, 0_u32, Bytes.empty)
        connection.socket.write(ack_frame.to_bytes)
      end
      
      private def handle_ping_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        if (frame.flags & 0x01) == 0  # Not an ACK
          # Send PING ACK with same payload
          pong_frame = HTTP2Frame.new(0x06_u8, 0x01_u8, 0_u32, frame.payload)
          connection.socket.write(pong_frame.to_bytes)
        end
      end
      
      private def handle_rst_stream_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        stream_id = frame.stream_id
        connection.streams.delete(stream_id)
      end
      
      private def handle_goaway_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        connection.close
      end
      
      private def handle_window_update_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        # Update flow control windows
        if frame.stream_id == 0
          # Connection window update
        else
          # Stream window update  
          stream = connection.streams[frame.stream_id]?
          if stream && frame.payload.size >= 4
            increment = ((frame.payload[0].to_u32 & 0x7f) << 24) | 
                       (frame.payload[1].to_u32 << 16) |
                       (frame.payload[2].to_u32 << 8) | 
                       frame.payload[3].to_u32
            stream.window_size += increment.to_i32
          end
        end
      end
      
      private def process_request(connection : HTTP2Connection, stream : HTTP2Stream)
        # Convert HTTP/2 headers to HTTP/1.1 request
        method = stream.headers[":method"]? || "GET"
        path = stream.headers[":path"]? || "/"
        
        # Create request object
        request = create_http1_request(method, path, stream.headers, stream.data.to_s)
        
        # Process through handler
        response = @handler.call(request)
        
        # Send response back via HTTP/2
        send_response(connection, stream, response)
      end
      
      private def send_response(connection : HTTP2Connection, stream : HTTP2Stream, response : Http::Response)
        # Send HEADERS frame with response headers
        headers = {
          ":status" => response.status_code.to_s
        }
        
        response.headers.each do |key, value|
          headers[key.downcase] = value.is_a?(Array) ? value.join(", ") : value.to_s
        end
        
        headers_payload = encode_headers(headers)
        headers_frame = HTTP2Frame.new(0x01_u8, 0x04_u8, stream.id, headers_payload) # END_HEADERS
        connection.socket.write(headers_frame.to_bytes)
        
        # Send DATA frame with response body
        if body = response.body
          body_data = body.is_a?(String) ? body.to_slice : body.to_s.to_slice
          data_frame = HTTP2Frame.new(0x00_u8, 0x01_u8, stream.id, body_data) # END_STREAM
          connection.socket.write(data_frame.to_bytes)
        else
          # Empty body, send empty DATA frame with END_STREAM
          data_frame = HTTP2Frame.new(0x00_u8, 0x01_u8, stream.id, Bytes.empty)
          connection.socket.write(data_frame.to_bytes)
        end
        
        stream.state = :closed
        connection.streams.delete(stream.id)
      end
      
      private def create_http1_request(method : String, path : String, headers : Hash(String, String), body : String) : Http::Request
        # This is a simplified conversion - in practice, you'd need proper HTTP/1.1 request creation
        Http::Request.new(method, path, headers, body)
      end
      
      private def read_frame(socket : TCPSocket) : Bytes?
        # Read frame header (9 bytes)
        header = Bytes.new(9)
        bytes_read = socket.read(header)
        return nil if bytes_read == 0
        
        # Extract payload length
        length = (header[0].to_u32 << 16) | (header[1].to_u32 << 8) | header[2].to_u32
        
        # Read payload
        frame_data = header + Bytes.new(length)
        if length > 0
          payload_bytes = socket.read(frame_data[9, length])
          return nil if payload_bytes == 0
        end
        
        frame_data
      end
      
      private def encode_settings(settings : Hash(Symbol, UInt32)) : Bytes
        payload = Bytes.new(settings.size * 6)
        offset = 0
        
        settings.each do |key, value|
          setting_id = case key
                      when :header_table_size then 1_u16
                      when :enable_push then 2_u16
                      when :max_concurrent_streams then 3_u16
                      when :initial_window_size then 4_u16
                      when :max_frame_size then 5_u16
                      when :max_header_list_size then 6_u16
                      else 0_u16
                      end
          
          payload[offset] = (setting_id >> 8).to_u8
          payload[offset + 1] = setting_id.to_u8
          payload[offset + 2] = (value >> 24).to_u8
          payload[offset + 3] = (value >> 16).to_u8
          payload[offset + 4] = (value >> 8).to_u8
          payload[offset + 5] = value.to_u8
          
          offset += 6
        end
        
        payload
      end
      
      private def decode_settings(payload : Bytes) : Hash(Symbol, UInt32)
        settings = Hash(Symbol, UInt32).new
        offset = 0
        
        while offset + 6 <= payload.size
          setting_id = (payload[offset].to_u16 << 8) | payload[offset + 1].to_u16
          value = (payload[offset + 2].to_u32 << 24) |
                  (payload[offset + 3].to_u32 << 16) |
                  (payload[offset + 4].to_u32 << 8) |
                  payload[offset + 5].to_u32
          
          key = case setting_id
                when 1 then :header_table_size
                when 2 then :enable_push
                when 3 then :max_concurrent_streams
                when 4 then :initial_window_size
                when 5 then :max_frame_size
                when 6 then :max_header_list_size
                else nil
                end
          
          settings[key] = value if key
          offset += 6
        end
        
        settings
      end
      
      # Simplified header encoding/decoding (real implementation would use HPACK)
      private def encode_headers(headers : Hash(String, String)) : Bytes
        io = IO::Memory.new
        headers.each do |key, value|
          io.write("#{key}: #{value}\r\n".to_slice)
        end
        io.to_slice
      end
      
      private def decode_headers(payload : Bytes) : Hash(String, String)
        headers = Hash(String, String).new
        String.new(payload).split("\r\n").each do |line|
          if colon_pos = line.index(':')
            key = line[0...colon_pos].strip
            value = line[colon_pos + 1..-1].strip
            headers[key] = value
          end
        end
        headers
      end
      
      private def handle_priority_frame(connection : HTTP2Connection, frame : HTTP2Frame)
        # Priority handling - simplified implementation
      end
    end
  end
end