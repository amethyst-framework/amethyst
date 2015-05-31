macro private_new_method
  private def new(*args)
    instance = Class.allocate
    instance.initialize(*args)
    instance
  end
  #private def self.new
    #super
  #end
end

macro singleton(method)
  #private_new_method
  def self.{{method.id}}(*args)
    @@instance ||= new(*args)
  end
end