class Params

	def initialize(default="")
		@params = Hash(String, String).new(default)
	end

	def [](key)
		@params[key.to_s]
	end

	def from_hash(hash : Hash)
	  hash.each { |k,v| @params[k.to_s] = v.to_s }
	end

	def []=(k,v)
		@params[k.to_s] = v.to_s
	end

	def ==(other : Hash)
		other == @params
	end

	def inspect
		@params.inspect
	end

	forward_missing_to @params
end