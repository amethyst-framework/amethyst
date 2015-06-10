abstract class Controller
  getter   :actions_hash
  getter   :request
  property :response
  property :body

  include Support::ControllerHelpers

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
  def initialize(@request : Http::Request, @response : Http::Response)
    @actions_hash = {} of String => ->
    add_actions
  end
  
  # Works like Ruby's send(:method) to invoke controller action:
  # NameController.call_action("show")
  def call_action(action)
    @actions_hash.fetch(action).call()
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