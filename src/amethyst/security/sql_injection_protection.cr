require "db"

module Amethyst
  module Security
    # SQL Injection protection helpers
    module SQLProtection
      # SQL query builder with automatic parameterization
      class QueryBuilder
        @table : String
        @select_fields : Array(String)
        @where_conditions : Array(String)
        @where_params : Array(DB::Any)
        @joins : Array(String)
        @order_by : Array(String)
        @group_by : Array(String)
        @having_conditions : Array(String)
        @having_params : Array(DB::Any)
        @limit_value : Int32?
        @offset_value : Int32?
        
        def initialize(@table : String)
          @select_fields = ["*"]
          @where_conditions = [] of String
          @where_params = [] of DB::Any
          @joins = [] of String
          @order_by = [] of String
          @group_by = [] of String
          @having_conditions = [] of String
          @having_params = [] of DB::Any
        end
        
        def select(*fields : String) : QueryBuilder
          @select_fields = fields.to_a
          self
        end
        
        def where(condition : String, *params : DB::Any) : QueryBuilder
          @where_conditions << condition
          @where_params.concat(params.to_a)
          self
        end
        
        def where(conditions : Hash(String, DB::Any)) : QueryBuilder
          conditions.each do |column, value|
            safe_column = sanitize_identifier(column)
            @where_conditions << "#{safe_column} = ?"
            @where_params << value
          end
          self
        end
        
        def join(table : String, condition : String) : QueryBuilder
          safe_table = sanitize_identifier(table)
          @joins << "JOIN #{safe_table} ON #{condition}"
          self
        end
        
        def left_join(table : String, condition : String) : QueryBuilder
          safe_table = sanitize_identifier(table)
          @joins << "LEFT JOIN #{safe_table} ON #{condition}"
          self
        end
        
        def inner_join(table : String, condition : String) : QueryBuilder
          safe_table = sanitize_identifier(table)
          @joins << "INNER JOIN #{safe_table} ON #{condition}"
          self
        end
        
        def order(field : String, direction : String = "ASC") : QueryBuilder
          safe_field = sanitize_identifier(field)
          safe_direction = sanitize_sort_direction(direction)
          @order_by << "#{safe_field} #{safe_direction}"
          self
        end
        
        def group(field : String) : QueryBuilder
          safe_field = sanitize_identifier(field)
          @group_by << safe_field
          self
        end
        
        def having(condition : String, *params : DB::Any) : QueryBuilder
          @having_conditions << condition
          @having_params.concat(params.to_a)
          self
        end
        
        def limit(count : Int32) : QueryBuilder
          @limit_value = count if count > 0
          self
        end
        
        def offset(count : Int32) : QueryBuilder
          @offset_value = count if count >= 0
          self
        end
        
        def build : {String, Array(DB::Any)}
          query_parts = ["SELECT"]
          
          # SELECT clause
          query_parts << @select_fields.map { |field| sanitize_identifier(field) }.join(", ")
          
          # FROM clause
          safe_table = sanitize_identifier(@table)
          query_parts << "FROM #{safe_table}"
          
          # JOIN clauses
          if !@joins.empty?
            query_parts.concat(@joins)
          end
          
          # WHERE clause
          all_params = @where_params.dup
          if !@where_conditions.empty?
            query_parts << "WHERE #{@where_conditions.join(" AND ")}"
          end
          
          # GROUP BY clause
          if !@group_by.empty?
            query_parts << "GROUP BY #{@group_by.join(", ")}"
          end
          
          # HAVING clause
          if !@having_conditions.empty?
            query_parts << "HAVING #{@having_conditions.join(" AND ")}"
            all_params.concat(@having_params)
          end
          
          # ORDER BY clause
          if !@order_by.empty?
            query_parts << "ORDER BY #{@order_by.join(", ")}"
          end
          
          # LIMIT clause
          if limit = @limit_value
            query_parts << "LIMIT #{limit}"
          end
          
          # OFFSET clause
          if offset = @offset_value
            query_parts << "OFFSET #{offset}"
          end
          
          {query_parts.join(" "), all_params}
        end
        
        def to_sql : String
          build[0]
        end
        
        def params : Array(DB::Any)
          build[1]
        end
        
        private def sanitize_identifier(identifier : String) : String
          # Remove dangerous characters and validate identifier
          clean = identifier.gsub(/[^a-zA-Z0-9_]/, "")
          
          # Ensure it starts with letter or underscore
          unless clean.match(/^[a-zA-Z_]/)
            raise ArgumentError.new("Invalid identifier: #{identifier}")
          end
          
          # Prevent SQL keywords (basic list)
          dangerous_keywords = %w[
            drop delete truncate alter create insert update select union
            exec execute xp_ sp_ declare script
          ]
          
          if dangerous_keywords.includes?(clean.downcase)
            raise ArgumentError.new("Identifier cannot be SQL keyword: #{identifier}")
          end
          
          clean
        end
        
        private def sanitize_sort_direction(direction : String) : String
          case direction.upcase
          when "ASC", "DESC"
            direction.upcase
          else
            "ASC"
          end
        end
      end
      
      # Safe parameter binding helpers
      module ParameterBinding
        def self.bind_parameters(query : String, params : Array(DB::Any)) : String
          # This is for logging/debugging purposes only
          # Never use this for actual query execution
          result = query
          params.each do |param|
            result = result.sub("?", quote_value(param))
          end
          result
        end
        
        def self.quote_value(value : DB::Any) : String
          case value
          when String
            "'#{value.to_s.gsub("'", "''")}'"
          when Nil
            "NULL"
          when Bool
            value ? "TRUE" : "FALSE"
          when Int32, Int64, Float32, Float64
            value.to_s
          else
            "'#{value.to_s.gsub("'", "''")}'"
          end
        end
        
        def self.validate_parameter(param : DB::Any) : Bool
          case param
          when String
            # Check for SQL injection patterns
            dangerous_patterns = [
              /['";]/,                    # Quote characters
              /--/,                       # SQL comments
              /\/\*/,                     # Block comments
              /\bUNION\b/i,              # Union attacks
              /\bSELECT\b.*\bFROM\b/i,   # Subqueries
              /\bDROP\b/i,               # Drop statements
              /\bDELETE\b/i,             # Delete statements
              /\bINSERT\b/i,             # Insert statements
              /\bUPDATE\b/i,             # Update statements
              /\bEXEC\b/i,               # Execute statements
              /\bxp_\b/i,                # Extended procedures
              /\bsp_\b/i                 # System procedures
            ]
            
            !dangerous_patterns.any? { |pattern| param.to_s.match(pattern) }
          else
            true
          end
        end
        
        def self.sanitize_like_pattern(pattern : String) : String
          # Escape LIKE wildcards to treat them as literal characters
          pattern.gsub("%", "\\%").gsub("_", "\\_")
        end
      end
      
      # Database connection wrapper with injection protection
      class SecureDatabase
        @db : DB::Database
        @query_timeout : Time::Span
        @max_query_length : Int32
        @enable_query_logging : Bool
        @query_whitelist : Set(String)?
        
        def initialize(@db : DB::Database, 
                       @query_timeout : Time::Span = 30.seconds,
                       @max_query_length : Int32 = 10000,
                       @enable_query_logging : Bool = false,
                       @query_whitelist : Set(String)? = nil)
        end
        
        def query(sql : String, *params : DB::Any, &block : DB::ResultSet -> T) forall T
          validate_query(sql, params.to_a)
          
          if @enable_query_logging
            log_query(sql, params.to_a)
          end
          
          @db.query(sql, args: params.to_a) do |rs|
            yield rs
          end
        end
        
        def exec(sql : String, *params : DB::Any) : DB::ExecResult
          validate_query(sql, params.to_a)
          
          if @enable_query_logging
            log_query(sql, params.to_a)
          end
          
          @db.exec(sql, args: params.to_a)
        end
        
        def scalar(sql : String, *params : DB::Any) : DB::Any
          validate_query(sql, params.to_a)
          
          if @enable_query_logging
            log_query(sql, params.to_a)
          end
          
          @db.scalar(sql, args: params.to_a)
        end
        
        def transaction(&block : DB::Transaction -> T) forall T
          @db.transaction do |tx|
            yield tx
          end
        end
        
        def close
          @db.close
        end
        
        # Safe query builders
        def from(table : String) : QueryBuilder
          QueryBuilder.new(table)
        end
        
        def execute_builder(builder : QueryBuilder, &block : DB::ResultSet -> T) forall T
          sql, params = builder.build
          query(sql, *params) do |rs|
            yield rs
          end
        end
        
        def execute_builder(builder : QueryBuilder) : DB::ExecResult
          sql, params = builder.build
          exec(sql, *params)
        end
        
        # Common safe operations
        def find_by_id(table : String, id : Int32 | Int64) : DB::ResultSet?
          safe_table = sanitize_table_name(table)
          query("SELECT * FROM #{safe_table} WHERE id = ? LIMIT 1", id) do |rs|
            rs.move_next ? rs : nil
          end
        end
        
        def find_by(table : String, conditions : Hash(String, DB::Any)) : Array(Hash(String, DB::Any))
          builder = from(table).where(conditions)
          results = [] of Hash(String, DB::Any)
          
          execute_builder(builder) do |rs|
            rs.each do
              row = {} of String => DB::Any
              rs.column_names.each_with_index do |name, index|
                row[name] = rs.read
              end
              results << row
            end
          end
          
          results
        end
        
        def insert(table : String, data : Hash(String, DB::Any)) : DB::ExecResult
          safe_table = sanitize_table_name(table)
          columns = data.keys.map { |k| sanitize_column_name(k) }
          placeholders = Array.new(data.size, "?")
          
          sql = "INSERT INTO #{safe_table} (#{columns.join(", ")}) VALUES (#{placeholders.join(", ")})"
          exec(sql, *data.values)
        end
        
        def update(table : String, id : Int32 | Int64, data : Hash(String, DB::Any)) : DB::ExecResult
          safe_table = sanitize_table_name(table)
          set_clauses = data.keys.map { |k| "#{sanitize_column_name(k)} = ?" }
          
          sql = "UPDATE #{safe_table} SET #{set_clauses.join(", ")} WHERE id = ?"
          params = data.values + [id]
          exec(sql, *params)
        end
        
        def delete_by_id(table : String, id : Int32 | Int64) : DB::ExecResult
          safe_table = sanitize_table_name(table)
          exec("DELETE FROM #{safe_table} WHERE id = ?", id)
        end
        
        private def validate_query(sql : String, params : Array(DB::Any))
          # Check query length
          if sql.size > @max_query_length
            raise ArgumentError.new("Query too long: #{sql.size} characters (max: #{@max_query_length})")
          end
          
          # Check for dangerous patterns
          dangerous_patterns = [
            /;\s*(DROP|DELETE|TRUNCATE|ALTER)/i,     # Dangerous operations after semicolon
            /UNION.*SELECT/i,                        # Union-based injections
            /--.*\n.*\b(SELECT|INSERT|UPDATE|DELETE)\b/i,  # Comment-based injections
            /\/\*.*\*\/.*\b(SELECT|INSERT|UPDATE|DELETE)\b/i, # Block comment injections
            /\bEXEC\b|\bEXECUTE\b/i,                # Execute statements
            /\bxp_|\bsp_/i,                         # System procedures
            /\bINTO\s+OUTFILE\b/i,                  # File operations
            /\bLOAD_FILE\b/i,                       # File reading
            /\bSCRIPT\b/i                           # Script execution
          ]
          
          dangerous_patterns.each do |pattern|
            if sql.match(pattern)
              raise ArgumentError.new("Potentially dangerous SQL pattern detected in query")
            end
          end
          
          # Validate parameters
          params.each do |param|
            unless ParameterBinding.validate_parameter(param)
              raise ArgumentError.new("Invalid parameter detected: #{param}")
            end
          end
          
          # Check against whitelist if provided
          if whitelist = @query_whitelist
            normalized_query = normalize_query(sql)
            unless whitelist.includes?(normalized_query)
              raise ArgumentError.new("Query not in whitelist")
            end
          end
        end
        
        private def log_query(sql : String, params : Array(DB::Any))
          # Safe logging without exposing sensitive data
          param_types = params.map { |p| p.class.name }
          Base::App.logger.log_string "SQL Query: #{sql} | Param types: #{param_types}"
        end
        
        private def normalize_query(sql : String) : String
          # Normalize query for whitelist comparison
          sql.gsub(/\s+/, " ")
             .strip
             .downcase
        end
        
        private def sanitize_table_name(table : String) : String
          # Only allow alphanumeric characters and underscores
          clean = table.gsub(/[^a-zA-Z0-9_]/, "")
          
          if clean != table
            raise ArgumentError.new("Invalid table name: #{table}")
          end
          
          clean
        end
        
        private def sanitize_column_name(column : String) : String
          # Only allow alphanumeric characters and underscores
          clean = column.gsub(/[^a-zA-Z0-9_]/, "")
          
          if clean != column
            raise ArgumentError.new("Invalid column name: #{column}")
          end
          
          clean
        end
      end
      
      # ORM-style model with automatic SQL injection protection
      abstract class SecureModel
        macro table(name)
          @@table_name = {{name.stringify}}
          
          def self.table_name
            @@table_name
          end
        end
        
        macro column(name, type)
          property {{name.id}} : {{type}}?
          
          @@columns ||= [] of String
          @@columns << {{name.stringify}}
        end
        
        def self.find(id : Int32 | Int64) : self?
          db = get_database
          result = db.find_by_id(table_name, id)
          return nil unless result
          
          from_result_set(result)
        end
        
        def self.where(conditions : Hash(String, DB::Any)) : Array(self)
          db = get_database
          results = db.find_by(table_name, conditions)
          
          results.map { |row| from_hash(row) }
        end
        
        def self.all(limit : Int32 = 1000) : Array(self)
          db = get_database
          builder = db.from(table_name).limit(limit)
          results = [] of self
          
          db.execute_builder(builder) do |rs|
            rs.each do
              results << from_result_set(rs)
            end
          end
          
          results
        end
        
        def save : Bool
          db = get_database
          
          if id = @id
            # Update existing record
            data = to_hash
            data.delete("id")
            result = db.update(self.class.table_name, id, data)
            result.rows_affected > 0
          else
            # Insert new record
            data = to_hash
            data.delete("id")
            result = db.insert(self.class.table_name, data)
            @id = result.last_insert_id
            true
          end
        end
        
        def delete : Bool
          return false unless id = @id
          
          db = get_database
          result = db.delete_by_id(self.class.table_name, id)
          result.rows_affected > 0
        end
        
        abstract def to_hash : Hash(String, DB::Any)
        # Subclasses should implement: def self.from_hash(hash : Hash(String, DB::Any)) : self
        # Subclasses should implement: def self.from_result_set(rs : DB::ResultSet) : self
        # Subclasses should implement: def self.get_database : SecureDatabase
      end
    end
    
    # SQL Injection protection middleware
    class SQLInjectionProtection < Middleware::Base
      @check_query_params : Bool
      @check_form_data : Bool
      @check_json_data : Bool
      @max_param_length : Int32
      @blocked_patterns : Array(Regex)
      
      def initialize(@app : Middleware::Base | Routing::OptimizedRouter?)
        super(@app)
        @check_query_params = true
        @check_form_data = true
        @check_json_data = true
        @max_param_length = 1000
        
        @blocked_patterns = [
          /['";]/,                      # Quote characters
          /--/,                         # SQL comments  
          /\/\*/,                       # Block comments
          /\bUNION\b.*\bSELECT\b/i,    # Union attacks
          /\bDROP\b.*\bTABLE\b/i,      # Drop table
          /\bDELETE\b.*\bFROM\b/i,     # Delete statements
          /\bINSERT\b.*\bINTO\b/i,     # Insert statements
          /\bUPDATE\b.*\bSET\b/i,      # Update statements
          /\bEXEC\b|\bEXECUTE\b/i      # Execute statements
        ]
      end
      
      def call(request) : Http::Response
        # Check query parameters
        if @check_query_params && request.query
          check_for_sql_injection(request.query.not_nil!, "query parameter")
        end
        
        # Check form data
        if @check_form_data && request.body
          case request.headers["Content-Type"]?
          when .try(&.includes?("application/x-www-form-urlencoded"))
            check_for_sql_injection(request.body.to_s, "form data")
          end
        end
        
        # Check JSON data
        if @check_json_data && request.body
          case request.headers["Content-Type"]?
          when .try(&.includes?("application/json"))
            check_json_for_sql_injection(request.body.to_s)
          end
        end
        
        @app.call(request)
      end
      
      private def check_for_sql_injection(data : String, context : String)
        return if data.empty?
        
        # Check length
        if data.size > @max_param_length
          raise ArgumentError.new("Parameter too long in #{context}")
        end
        
        # Check for dangerous patterns
        @blocked_patterns.each do |pattern|
          if data.match(pattern)
            Base::App.logger.log_string "SQL injection attempt detected in #{context}: #{data}"
            raise ArgumentError.new("SQL injection attempt detected in #{context}")
          end
        end
      end
      
      private def check_json_for_sql_injection(json_str : String)
        begin
          json = JSON.parse(json_str)
          check_json_recursive(json, "JSON data")
        rescue JSON::ParseException
          # Not valid JSON, skip check
        end
      end
      
      private def check_json_recursive(json : JSON::Any, context : String)
        case json.raw
        when String
          check_for_sql_injection(json.as_s, context)
        when Hash
          json.as_h.each_value do |value|
            check_json_recursive(value, context)
          end
        when Array
          json.as_a.each do |item|
            check_json_recursive(item, context)
          end
        end
      end
    end
  end
end