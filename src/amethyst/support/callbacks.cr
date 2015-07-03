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

   macro define_callbacks(*callbacks)
    {% for callback in callbacks %}
      @{{callback.id}}_callbacks = CallbackSequence.new
      def _{{callback.id}}_callbacks
      	@{{callback.id}}_callbacks
      end
    {% end %}
		{{debug()}}
  end

  macro proc_from_method_name_symbol(symbol)
    ->{{symbol.id}}
  end

  macro set_callback(callback, kind, method)
	  def _set_{{kind.id}}_{{method.id}}_{{callback.id}}
	    @{{callback.id}}_callbacks.{{kind.id}}(->{{method.id}})
	  end
	  {{debug()}}
  end


end


			