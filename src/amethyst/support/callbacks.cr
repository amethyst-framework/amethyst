module Callbacks

	class CallbackSequence

		def initialize
			@before = [] of -> Bool
			@after  = [] of -> Bool
		end

		def before(before)
      @before.unshift(before)
      self
    end

    def after(after)
      @after.push(after)
      self
    end

    def length
    	@before.length+@after.length
    end

    # invokes before callbacks each by one, than run code and invokes after callbacks
		def call(&block)
			result = true
			@before.each do |before_callback| 
				break result = false  unless before_callback.call
			end
			if result
				result = yield
        @after.each do |after_callback| 
				  break result = false unless after_callback.call
				end
			end
			result
		end
	end

	macro run_callbacks(callback, &block)
	  callback_sequence = _{{callback.id}}_callbacks
	  callback_sequence.call do
	  	{{yield}}
	  end
	  {{debug()}}
	end

  macro define_callbacks(*callbacks)
    {% for callback in callbacks %}
      def _{{callback.id}}_callbacks
      	@{{callback.id}}_callbacks ||= CallbackSequence.new
      end
    {% end %}
		{{debug()}}
  end

  macro set_callback(callback, kind, method)
	  _{{callback.id}}_callbacks.{{kind.id}}(->{{method.id}})
	  {{debug()}}
  end

end


# class Hello
#   include Callbacks
  
#   define_callbacks :on_hello
  
#   def initialize
#     set_callback :on_hello, :after, :callback
#   end
  
#   def run_callback
#     run_callbacks :on_hello do
#       p "method"
#     end
#   end
  
#   def callback
#     p "hello"
#     true
#   end
# end

# hello = Hello.new
# hello.run_callback

			