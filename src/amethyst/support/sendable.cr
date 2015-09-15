module Amethyst
  module Support
    module Sendable
      class WrongNumberOfArguments < Exception
        def initialize(method, given, expected)
          super("Wrong number of arguments for '#{method}' (#{given} for #{expected})")
        end
      end

      class WrongInstanceMethod < Exception
        def initialize(klass, method)
          super("Instance of '#{klass}' class has no '#{method}' method")
        end
      end

      # Allows to invoke objects methods through 'send' method.
      macro create_send
        case method
          {% methods = @type.methods %}
          {% for m in methods %}
          {% args = m.args %}
        when "{{m.name.id}}"
          raise WrongNumberOfArguments.new({{m.name.stringify}}, args.length, {{m.args.length}}) unless args.length == {{m.args.length}}
          {{m.name.id}}{% unless args.empty? %}(
          {% for arg in args %}{{arg.id}}=args[:{{arg.id}}],{% end %}){% end %}
          {% end %}
        else
          raise WrongInstanceMethod.new({{@type.name.stringify}}, "#{method}")
        end
      end

      def send(method, args={} of Symbol => String)
        create_send
      end
    end
  end
end

# class A
#   include Sendable

#   def call(a,b)
#     p a
#     p b
#   end

#   def hello
#    p "hello"
#   end
# end

# a = A.new
# a.send "call", {a: "a", b: "b"}
# a.send "hello"
