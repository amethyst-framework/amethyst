module Amethyst
  module Routing
    class RadixNode
      property path : String
      property full_path : String
      property handler : Hash(String, Routing::BaseRoute | String | Symbol)?
      property children : Hash(String, RadixNode)
      property param_names : Array(String)
      property param_name : String?  # Individual parameter name for this node
      property wildcard_child : RadixNode?
      property param_child : RadixNode?
      property is_leaf : Bool
      
      def initialize(@path : String = "", @param_name : String? = nil)
        @full_path = ""
        @handler = nil
        @children = {} of String => RadixNode
        @param_names = [] of String
        @wildcard_child = nil
        @param_child = nil
        @is_leaf = false
      end
    end

    class RadixTree
      @root : RadixNode
      
      def initialize
        @root = RadixNode.new
      end
      
      def insert(path : String, handler : Routing::BaseRoute, method : String)
        node = @root
        param_names = [] of String
        
        # Handle root path as special case
        if path == "/"
          node.is_leaf = true
          node.full_path = path
          node.param_names = param_names
          node.handler = {method => handler.as(Routing::BaseRoute | String | Symbol)}
          return
        end
        
        # Split path into segments by '/'
        segments = path.split('/').reject(&.empty?)
        
        segments.each do |segment|
          if segment.starts_with?(':')
            # Parameter segment like ":id"
            param_name = segment[1..-1]  # Remove the ':'
            param_names << param_name
            
            if node.param_child.nil?
              node.param_child = RadixNode.new(":param", param_name)
            end
            
            node = node.param_child.not_nil!
          elsif segment.starts_with?('*')
            # Wildcard segment like "*path"
            param_name = segment[1..-1]  # Remove the '*'
            param_names << param_name
            
            if node.wildcard_child.nil?
              node.wildcard_child = RadixNode.new("*", param_name)
            end
            
            node = node.wildcard_child.not_nil!
            break  # Wildcard consumes the rest
          else
            # Regular segment like "users" or "posts"
            segment_with_slash = "/#{segment}"
            
            if !node.children.has_key?(segment_with_slash)
              node.children[segment_with_slash] = RadixNode.new(segment_with_slash)
            end
            
            node = node.children[segment_with_slash]
          end
        end
        
        node.is_leaf = true
        node.full_path = path
        node.param_names = param_names
        node.handler = {method => handler.as(Routing::BaseRoute | String | Symbol)}
      end
      
      def find(path : String, method : String) : {route: Routing::BaseRoute?, params: Hash(String, String)}
        node = @root
        params = {} of String => String
        
        # Handle root path as special case
        if path == "/"
          if node.is_leaf && node.handler && node.handler.not_nil!.has_key?(method)
            return {route: node.handler.not_nil![method].as(Routing::BaseRoute), params: params}
          else
            return {route: nil.as(Routing::BaseRoute?), params: params}
          end
        end
        
        i = 0
        
        while i < path.size && node
          # Try exact match first
          segment_end = path.index('/', i + 1) || path.size
          segment = path[i...segment_end]
          
          if node.children.has_key?(segment)
            node = node.children[segment]
            i = segment_end
          elsif node.param_child
            # Parameter match
            param_value = segment.lstrip('/')
            param_child = node.param_child.not_nil!
            if param_name = param_child.param_name
              params[param_name] = param_value
            end
            node = param_child
            i = segment_end
          elsif node.wildcard_child
            # Wildcard match - consume rest of path
            wildcard_child = node.wildcard_child.not_nil!
            if param_name = wildcard_child.param_name
              params[param_name] = path[i..-1].lstrip('/')
            end
            node = wildcard_child
            break
          else
            return {route: nil.as(Routing::BaseRoute?), params: params}
          end
        end
        
        if node && node.is_leaf && node.handler && node.handler.not_nil!.has_key?(method)
          return {route: node.handler.not_nil![method].as(Routing::BaseRoute), params: params}
        end
        
        {route: nil.as(Routing::BaseRoute?), params: params}
      end
      
      def compile_routes : Hash(String, RadixNode)
        compiled = {} of String => RadixNode
        compile_node(@root, "", compiled)
        compiled
      end
      
      private def compile_node(node : RadixNode, prefix : String, compiled : Hash(String, RadixNode))
        current_path = prefix + node.path
        
        if node.is_leaf
          compiled[current_path] = node
        end
        
        node.children.each do |segment, child|
          compile_node(child, current_path, compiled)
        end
        
        if param_child = node.param_child
          compile_node(param_child, current_path, compiled)
        end
        
        if wildcard_child = node.wildcard_child
          compile_node(wildcard_child, current_path, compiled)
        end
      end
    end
  end
end