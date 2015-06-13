abstract class Controller
  getter   :actions_hash
  property :request
  property :response
  property :body

  include Support::ControllerHelpers

  class Formatter
    getter :processed

    def initialize(request : Http::Request, response : Http::Response)
      @response  = response
      @request   = request
      @processed = false
    end
    
    # Do stuff in block if client accepts text/html
    def html(&block)
      if @request.accept == "text/html"
        @response.status = 200
        @response.header "Content-type", "text/html"
        yield
        @processed = true
      end
    end

    def any(&block)
      @response.status = 200
      @response.header "Content-type", "text/html"
      yield
      @processed = true
    end
  end

  # This hack creates procs from controller actions, and adds it to the @actions_hash
  macro actions(*actions)
    private def add_actions
      {% for action in actions %}
        @actions_hash[{{action}}.to_s] = ->{{action.id}}
      {% end %}
    end
  end

  # Creates a hash for controller actions
  # Then, invokes actions method to add actions to the hash
  def initialize()
    @request :: Http::Request
    @response :: Http::Response
    @actions_hash = {} of String => ->
    add_actions
  end

  def set_env(@request, @response)
  end

  def respond_to(&block)
    formatter = Formatter.new(@request, @response)
    yield formatter
    raise Exceptions::HttpBadRequest.new() unless formatter.processed
  end
  
  # Works like Ruby's send(:method) to invoke controller action:
  # NameController.call_action("show")
  def call_action(action)
    raise Exceptions::ControllerActionNotFound.new(action, self.class.name) unless @actions_hash.has_key? action
    @actions_hash[action].call
    @response
  end

  def to_s(io : IO)
    msg = "self.name\n"
    @actions_hash.each do |action|
      msg += "#{action}\n"
    end
    io << msg
  end
end

# TODO: Separate module for html, answer etc. (mixin module)
# TODO: Implement Http errors handling middleware