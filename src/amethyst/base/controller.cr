require "../support/*"

module Amethyst
  module Base
    abstract class Controller
      getter   :actions
      property :request
      property :response
      property :body
      getter   :params

      include Amethyst::Support::ControllerHelpers
      include Amethyst::Sugar::View
      include Amethyst::Support::Sendable

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

      macro before_action(callback, only=[] of Symbol)
        {% if only.empty? %}
          {% only = @type.methods.map(&.name.stringify) %}
        {% end %}
        {% for action in only %}
          def _before_{{action.id}}_{{callback.id}}
          @before_callbacks["{{action.id}}"] = [] of (-> Bool) unless @before_callbacks["{{action.id}}"]?
          @before_callbacks["{{action.id}}"] << ->{{callback.id}}
          end
        {% end %}
      end

      macro register_before_action_callbacks
        {% method_names = @type.methods.map(&.name.stringify) %}
            {% before_callbacks = method_names.select(&.starts_with?("_before_")) %}
        {% for method in before_callbacks %}
          {{method.id}}
        {% end %}
      end

      # Creates a hash for controller actions
      # Then, invokes actions method to add actions to the hash
      def initialize()
        @request :: Http::Request
        @response :: Http::Response
        @actions = {} of String => ->
        add_actions
        @before_callbacks = {} of String => Array
        register_before_action_callbacks
      end

      def params
        request.parameters
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
        raise Exceptions::ControllerActionNotFound.new(action, self.class.name) unless @actions.has_key? action
        callback_result = true
        if before_callbacks = @before_callbacks[action]?
          callback_result = before_callbacks.each do |callback|
            break false unless callback.call
          end
        end
        @actions[action].call if callback_result
        @response
      end

      def to_s(io : IO)
        msg = "self.name\n"
        @actions.each do |action|
          msg += "#{action}\n"
        end
        io << msg
      end
    end
  end
end

# TODO: Implement Http errors handling middleware
