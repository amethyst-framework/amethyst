module Callbacks

	class CallbackSequence

		def initialize
			@before = [] of Proc
			@after  = [] of Proc
		end

		def before(before : Proc)
      @before.unshift(before)
      self
    end

    def after(after : Proc)
      @after.push(after)
      self
    end

    # invokes before callbacks each by one, than run code and invokes after callbacks
		def call(&block)
			result = true
			result = @before.each do |before_callback| 
				break false unless callback.call
			end
			if result
				block.call
        result = @before.each do |before_callback| 
				  break false unless callback.call
				end
			end
			result
		end
	end


			