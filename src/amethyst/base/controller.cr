abstract class Controller
  getter   :actions_hash
  getter   :request
  property :response
  property :body

  # This hack creates procs from controller actions, and adds it to the @actions_hash
  macro actions(*actions)
    def add_actions
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
    #if $app.env == :development
      #puts "Action #{action} invoked"
    #end
    @actions_hash.fetch(action).call()
    return @response
  end

  def html(body : String)
    @response.body = body
    @response.header("Content-Type", "text/html")
  end
end

# TODO: Separate module for html, answer etc. (mixin module)