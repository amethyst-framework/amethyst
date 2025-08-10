require "./radix_tree"

module Amethyst
  module Routing
    class OptimizedRouter
      @@instance : OptimizedRouter?
      
      @trees : Hash(String, RadixTree)
      @compiled : Bool
      @route_cache : Hash(String, {route: Routing::BaseRoute?, params: Hash(String, String)})
      @cache_size_limit : Int32
      
      def self.instance
        @@instance ||= new
      end
      
      def initialize(@cache_size_limit = 1000)
        @trees = Hash(String, RadixTree).new
        @compiled = false
        @route_cache = Hash(String, {route: Routing::BaseRoute?, params: Hash(String, String)}).new
        
        Http::METHODS.each do |method|
          @trees[method] = RadixTree.new
        end
      end
      
      def add_route(method : String, path : String, route : Routing::BaseRoute)
        tree = @trees[method]?
        return unless tree
        
        tree.insert(path, route, method)
        @compiled = false
        clear_cache
      end
      
      def find_route(method : String, path : String) : {route: Routing::BaseRoute?, params: Hash(String, String)}
        cache_key = "#{method}:#{path}"
        
        if cached = @route_cache[cache_key]?
          return cached
        end
        
        tree = @trees[method]?
        return {route: nil.as(Routing::BaseRoute?), params: {} of String => String} unless tree
        
        result = tree.find(path, method)
        
        # Cache result if within size limit
        if @route_cache.size < @cache_size_limit
          @route_cache[cache_key] = result
        end
        
        result
      end
      
      def compile!
        return if @compiled
        
        @trees.each do |method, tree|
          tree.compile_routes
        end
        
        @compiled = true
      end
      
      def clear_cache
        @route_cache.clear
      end
      
      def call(request : Http::Request) : Http::Response
        result = find_route(request.method, request.path)
        
        if route = result[:route]
          # Create a simple context (this should be more sophisticated)
          fake_io = IO::Memory.new
          context = HTTP::Context.new(request.to_http_request, fake_io)
          
          # Call the route
          route.call(context)
          
          # Extract response from context (simplified)
          Http::Response.new(200, "OK")
        else
          Http::Response.new(404, "Not Found")
        end
      end
      
      def stats
        {
          routes_count: @trees.values.sum { |tree| count_routes(tree) },
          cache_size: @route_cache.size,
          compiled: @compiled
        }
      end
      
      private def count_routes(tree : RadixTree) : Int32
        tree.compile_routes.size
      end
    end
  end
end