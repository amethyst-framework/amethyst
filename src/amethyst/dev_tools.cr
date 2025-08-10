module Amethyst
  module DevTools
    # File watcher for hot reloading
    class FileWatcher
      @watched_dirs : Array(String)
      @file_mtimes : Hash(String, Time)
      @on_change : Proc(String, Nil)
      
      def initialize(@watched_dirs : Array(String))
        @file_mtimes = {} of String => Time
        @on_change = ->(path : String) {}
        
        # Initial scan
        scan_files
      end
      
      def on_change(&block : String ->)
        @on_change = block
      end
      
      def start
        spawn do
          loop do
            check_for_changes
            sleep 0.5
          end
        end
      end
      
      private def scan_files
        @watched_dirs.each do |dir|
          Dir.glob("#{dir}/**/*.cr").each do |file|
            @file_mtimes[file] = File.info(file).modification_time
          end
        end
      end
      
      private def check_for_changes
        @watched_dirs.each do |dir|
          Dir.glob("#{dir}/**/*.cr").each do |file|
            mtime = File.info(file).modification_time
            
            if !@file_mtimes.has_key?(file) || @file_mtimes[file] < mtime
              @file_mtimes[file] = mtime
              @on_change.call(file)
            end
          end
        end
      end
    end
    
    # Development server with hot reload
    class DevServer
      @app : Application
      @port : Int32
      @process : Process?
      
      def initialize(@app, @port = 3000)
      end
      
      def start
        Log.info { "Starting development server with hot reload..." }
        
        # Start file watcher
        watcher = FileWatcher.new(["src", "config"])
        watcher.on_change do |file|
          Log.info { "File changed: #{file}" }
          restart_server
        end
        watcher.start
        
        # Start initial server
        start_server
        
        # Keep main process running
        Signal::INT.trap do
          Log.info { "Shutting down..." }
          stop_server
          exit
        end
        
        sleep
      end
      
      private def start_server
        Log.info { "Starting server on port #{@port}..." }
        
        @process = Process.new(
          "crystal", 
          ["run", "src/app.cr", "--", "--port", @port.to_s],
          env: {"CRYSTAL_ENV" => "development"}
        )
      end
      
      private def stop_server
        if process = @process
          process.terminate
          process.wait
        end
      end
      
      private def restart_server
        Log.info { "Restarting server..." }
        stop_server
        start_server
      rescue ex
        Log.error { "Failed to restart: #{ex.message}" }
      end
    end
    
    # Error page with stack trace
    class ErrorPage
      def self.render(exception : Exception, request : ::HTTP::Request) : String
        <<-HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>Error - #{exception.class.name}</title>
          <style>
            body {
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
              margin: 0;
              padding: 0;
              background: #f5f5f5;
            }
            .container {
              max-width: 1200px;
              margin: 0 auto;
              padding: 20px;
            }
            .error-header {
              background: #e74c3c;
              color: white;
              padding: 30px;
              border-radius: 8px 8px 0 0;
            }
            .error-header h1 {
              margin: 0;
              font-size: 24px;
            }
            .error-message {
              font-size: 18px;
              margin-top: 10px;
              opacity: 0.9;
            }
            .error-details {
              background: white;
              padding: 30px;
              border-radius: 0 0 8px 8px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .request-info {
              background: #f8f9fa;
              padding: 20px;
              border-radius: 4px;
              margin-bottom: 20px;
            }
            .request-info h3 {
              margin-top: 0;
              color: #495057;
            }
            .info-row {
              display: flex;
              padding: 5px 0;
              border-bottom: 1px solid #dee2e6;
            }
            .info-label {
              font-weight: bold;
              width: 150px;
              color: #6c757d;
            }
            .info-value {
              flex: 1;
              font-family: 'Courier New', monospace;
            }
            .stack-trace {
              margin-top: 20px;
            }
            .stack-frame {
              background: #f8f9fa;
              padding: 15px;
              margin-bottom: 10px;
              border-radius: 4px;
              border-left: 4px solid #007bff;
            }
            .frame-location {
              font-family: 'Courier New', monospace;
              font-size: 14px;
              color: #495057;
            }
            .frame-method {
              font-weight: bold;
              color: #212529;
              margin-top: 5px;
            }
            .source-code {
              background: #282c34;
              color: #abb2bf;
              padding: 20px;
              border-radius: 4px;
              overflow-x: auto;
              margin-top: 10px;
            }
            .source-line {
              font-family: 'Courier New', monospace;
              font-size: 13px;
              line-height: 1.5;
            }
            .source-line-number {
              display: inline-block;
              width: 40px;
              color: #636d83;
              text-align: right;
              margin-right: 10px;
            }
            .source-line-current {
              background: #e06c75;
              color: white;
              display: block;
              margin: 0 -20px;
              padding: 0 20px;
            }
            .params-section {
              margin-top: 20px;
            }
            .params-table {
              width: 100%;
              border-collapse: collapse;
            }
            .params-table th {
              text-align: left;
              padding: 10px;
              background: #f8f9fa;
              border-bottom: 2px solid #dee2e6;
            }
            .params-table td {
              padding: 10px;
              border-bottom: 1px solid #dee2e6;
              font-family: 'Courier New', monospace;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="error-header">
              <h1>#{exception.class.name}</h1>
              <div class="error-message">#{HTML.escape(exception.message || "")}</div>
            </div>
            
            <div class="error-details">
              <div class="request-info">
                <h3>Request Information</h3>
                <div class="info-row">
                  <div class="info-label">Method:</div>
                  <div class="info-value">#{request.method}</div>
                </div>
                <div class="info-row">
                  <div class="info-label">Path:</div>
                  <div class="info-value">#{request.path}</div>
                </div>
                <div class="info-row">
                  <div class="info-label">Query String:</div>
                  <div class="info-value">#{request.query || "none"}</div>
                </div>
                <div class="info-row">
                  <div class="info-label">Remote Address:</div>
                  <div class="info-value">#{request.remote_address}</div>
                </div>
              </div>
              
              #{render_params(request)}
              
              <div class="stack-trace">
                <h3>Stack Trace</h3>
                #{render_backtrace(exception)}
              </div>
            </div>
          </div>
        </body>
        </html>
        HTML
      end
      
      private def self.render_params(request : ::HTTP::Request) : String
        params = request.params
        return "" if params.to_h.empty?
        
        rows = params.to_h.map do |key, value|
          "<tr><td>#{HTML.escape(key)}</td><td>#{HTML.escape(value)}</td></tr>"
        end.join("\n")
        
        <<-HTML
        <div class="params-section">
          <h3>Parameters</h3>
          <table class="params-table">
            <thead>
              <tr>
                <th>Name</th>
                <th>Value</th>
              </tr>
            </thead>
            <tbody>
              #{rows}
            </tbody>
          </table>
        </div>
        HTML
      end
      
      private def self.render_backtrace(exception : Exception) : String
        return "No backtrace available" unless exception.backtrace?
        
        frames = exception.backtrace.map do |frame|
          if match = frame.match(/^(.+?):(\d+):(?:\d+:)?\s*(.*)$/)
            file = match[1]
            line = match[2].to_i
            method = match[3]
            
            source = render_source_code(file, line) if File.exists?(file)
            
            <<-HTML
            <div class="stack-frame">
              <div class="frame-location">#{HTML.escape(frame)}</div>
              #{source || ""}
            </div>
            HTML
          else
            <<-HTML
            <div class="stack-frame">
              <div class="frame-location">#{HTML.escape(frame)}</div>
            </div>
            HTML
          end
        end.join("\n")
        
        frames
      end
      
      private def self.render_source_code(file : String, error_line : Int32) : String?
        return nil unless File.exists?(file)
        
        lines = File.read_lines(file)
        start_line = Math.max(1, error_line - 5)
        end_line = Math.min(lines.size, error_line + 5)
        
        source_lines = (start_line..end_line).map do |line_num|
          line = lines[line_num - 1]? || ""
          escaped_line = HTML.escape(line)
          
          if line_num == error_line
            <<-HTML
            <div class="source-line source-line-current">
              <span class="source-line-number">#{line_num}</span>#{escaped_line}
            </div>
            HTML
          else
            <<-HTML
            <div class="source-line">
              <span class="source-line-number">#{line_num}</span>#{escaped_line}
            </div>
            HTML
          end
        end.join("")
        
        <<-HTML
        <div class="source-code">
          #{source_lines}
        </div>
        HTML
      rescue
        nil
      end
    end
    
    # Request logger with detailed information
    class RequestLogger
      def self.call(context : HTTP::Context, &block)
        start_time = Time.monotonic
        request_id = context.request.headers["X-Request-ID"]? || Random::Secure.urlsafe_base64(16)
        
        context.response.headers["X-Request-ID"] = request_id
        
        Log.with_context(request_id: request_id) do
          Log.info { "Started #{context.request.method} #{context.request.path}" }
          
          if context.request.query
            Log.debug { "Query: #{context.request.query}" }
          end
          
          begin
            yield
          ensure
            duration = Time.monotonic - start_time
            status = context.response.status
            
            level = case status
            when 500..599 then Log::Severity::Error
            when 400..499 then Log::Severity::Warn
            else Log::Severity::Info
            end
            
            Log.log(level) do
              "Completed #{status} in #{format_duration(duration)}"
            end
          end
        end
      end
      
      private def self.format_duration(span : Time::Span) : String
        if span.total_milliseconds < 1
          "#{(span.total_microseconds).round(2)}µs"
        elsif span.total_seconds < 1
          "#{span.total_milliseconds.round(2)}ms"
        else
          "#{span.total_seconds.round(2)}s"
        end
      end
    end
  end
end