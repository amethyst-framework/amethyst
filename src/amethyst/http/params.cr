class Params
	getter :hash

	def initialize(default="")
		@params = Hash(String, String).new(default)
	end

	def hash
		@params
	end

	def merge(other : Params)
		merged_hash = @params.merge other.hash
		merged_params = Params.new
		merged_params.from_hash(merged_hash)
		merged_params
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

	def has_keys?(keys_array : Array)
		has = true
		keys_array.each do |key|
			has = false unless @params.has_key? key.to_s
		end
		has
	end

  def to_s(io : IO)
    msg = "\n{\n"
    @params.each do |k,v|
      msg+="#{k} => #{v}\n"
    end
    msg +="\n}"
    io << msg
  end

	forward_missing_to @params
end