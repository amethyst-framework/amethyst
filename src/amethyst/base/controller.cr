abstract class Controller
  getter   :actions_hash
  property :request
  property :response
  property :body

  include Support::ControllerHelpers

  # This hack creates procs from controller actions, and adds it to the @actions_hash
  macro actions(*actions)
    private def add_actions
      # t_n = Time.now
      {% for action in actions %}
        @actions_hash[{{action}}.to_s] = ->{{action.id}}
      {% end %}
      # puts "Actions creating"+(t_n - Time.now).to_s
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

  class Formatter

    def initialize(response)
      @response = response
    end

    def html(&block)
      @response.header "Content-type", "text/html"
      @response.body = yield
    end
  end

  def respond_to(&block)
    formatter = Formatter.new(@response)
    yield formatter
  end
  
  # Works like Ruby's send(:method) to invoke controller action:
  # NameController.call_action("show")
  def call_action(action)
    raise Exceptions::ActionNotFound.new(action, self.class.name) unless @actions_hash.has_key? action
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