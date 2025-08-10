module Amethyst
  module Routing
    class RadixNode
      property path : String
      property full_path : String
      property handler : Hash(String, Routing::Route | String | Symbol)?
      property children : Hash(String, RadixNode)
      property param_names : Array(String)
      property wildcard_child : RadixNode?
      property param_child : RadixNode?
      property is_leaf : Bool
      
      def initialize(@path : String = "")
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
      
      def insert(path : String, handler, method : String)
        node = @root
        param_names = [] of String
        i = 0
        
        while i < path.size
          char = path[i]
          
          if char == ':'
            # Parameter segment
            param_start = i + 1
            param_end = path.index('/', param_start) || path.size
            param_name = path[param_start...param_end]
            param_names << param_name
            
            if node.param_child.nil?
              node.param_child = RadixNode.new(":param")
            end
            
            node = node.param_child.not_nil!
            i = param_end
          elsif char == '*'
            # Wildcard segment
            param_name = path[(i + 1)..-1]
            param_names << param_name
            
            if node.wildcard_child.nil?
              node.wildcard_child = RadixNode.new("*")
            end
            
            node = node.wildcard_child.not_nil!
            break
          else
            # Regular segment
            segment_end = path.index('/', i + 1) || path.size
            segment = path[i...segment_end]
            
            if !node.children.has_key?(segment)
              node.children[segment] = RadixNode.new(segment)
            end
            
            node = node.children[segment]
            i = segment_end
          end
        end
        
        node.is_leaf = true
        node.full_path = path
        node.param_names = param_names
        node.handler = {method => handler}
      end
      
      def find(path : String, method : String) : {handler: Routing::Route?, params: Hash(String, String)}
        node = @root
        params = {} of String => String
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
            if node.param_child.not_nil!.param_names.size > 0
              params[node.param_child.not_nil!.param_names[0]] = param_value
            end
            node = node.param_child
            i = segment_end
          elsif node.wildcard_child
            # Wildcard match - consume rest of path
            if node.wildcard_child.not_nil!.param_names.size > 0
              params[node.wildcard_child.not_nil!.param_names[0]] = path[i..-1].lstrip('/')
            end
            node = node.wildcard_child
            break
          else
            return {handler: nil, params: params}
          end
        end
        
        if node && node.is_leaf && node.handler && node.handler.not_nil!.has_key?(method)
          return {handler: node.handler.not_nil![method], params: params}
        end
        
        {handler: nil, params: params}
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