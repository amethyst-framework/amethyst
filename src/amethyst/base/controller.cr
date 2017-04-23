module Amethyst
  module Base
    abstract class Controller
      getter :actions
      property :request
      property :response
      property :body
      getter :params
      getter :name

      @name : String | Nil

      include Support::ControllerHelpers
      include Sugar::View
      include Support::Sendable

      class Formatter
        getter :processed

        def initialize(request : Http::Request, response : Http::Response)
          @response = response
          @request = request
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

      def body
        response.body
      end

      def session
        session_id = request.cookies["sid"]
        return Base::App.session.get_session(session_id)
      end

      def destroy_session
        session_id = request.cookies["sid"]
        return Base::App.session.destroy_session(session_id)
      end

      # This hack creates procs from controller actions, and adds it to the @actions
      macro actions(*actions)
        private def add_actions
          {% for action in actions %}
            @actions[{{action}}.to_s] = ->{{action.id}}
          {% end %}
        end
      end

      macro register_action_callbacks
        {% method_names = @type.methods.map(&.name.stringify) %}
            {% callbacks = method_names.select do |name|
                 name.starts_with?("_before_") || name.starts_with?("_after_")
               end %}
        def action_callbacks
          {% for method in callbacks %}
            {{method.id}}
          {% end %}
        end
      end

      macro before_action(callback, only = [] of Symbol)
        {% if only.empty? %}
          {% only = ["all"] %}
        {% end %}
        {% for action in only %}
          def _before_{{action.id}}_{{callback.id}}
            @before_callbacks["{{action.id}}"] = [] of (-> Array(String)) unless @before_callbacks["{{action.id}}"]?
            @before_callbacks["{{action.id}}"] << ->{{callback.id}}
          end
        {% end %}
        register_action_callbacks
      end

      macro after_action(callback, only = [] of Symbol)
        {% if only.empty? %}
          {% only = ["all"] %}
        {% end %}
        {% for action in only %}
          def _after_{{action.id}}_{{callback.id}}
            @after_callbacks["{{action.id}}"] = [] of (-> Array(String)) unless @after_callbacks["{{action.id}}"]?
            @after_callbacks["{{action.id}}"] << ->{{callback.id}}
          end
        {% end %}
        register_action_callbacks
      end

      # Creates a hash for controller actions
      # Then, invokes actions method to add actions to the hash
      def initialize
        @request = Http::Request.new(HTTP::Request.new("", ""))
        @response = Http::Response.new

        @actions = {} of String => ->
        add_actions
        @before_callbacks = {} of String => Array(Proc(Array(String)))
        @after_callbacks = {} of String => Array(Proc(Array(String)))
        action_callbacks
      end

      def params
        request.parameters
      end

      def set_env(@request, @response)
      end

      def respond_to(&block)
        formatter = Formatter.new(@request, @response)
        yield formatter
        raise Exceptions::HttpBadRequest.new unless formatter.processed
      end

      # Works like Ruby's send(:method) to invoke controller action:
      # NameController.call_action("show")
      def call_action(action)
        raise Exceptions::ControllerActionNotFound.new(action, self.class.name) unless @actions.has_key? action
        if do_callbacks @before_callbacks, action
          @actions[action].call
          do_callbacks @after_callbacks, action
        end
        @response
      end

      def to_s(io : IO)
        msg = "self.name\n"
        @actions.each do |action|
          msg += "#{action}\n"
        end
        io << msg
      end

      private def do_callbacks(callbacks, action)
        [callbacks[action.to_s]?, callbacks["all"]?].compact.each do |callbacks|
          callbacks.each do |callback|
            return false unless callback.call
          end
        end
        true
      end
      register_action_callbacks
    end
  end
end

# TODO: Implement Http errors handling middleware
