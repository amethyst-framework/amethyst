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

macro singleton_INSTANCE
  INSTANCE = new

  def self.instance
    INSTANCE
  end
end

macro singleton(method)
  #private_new_method
  def self.{{method.id}}(*args)
    @@instance ||= new(*args)
  end
end

macro instanciate(klass)
  begin
   {{klass.id}}.new
  rescue Exception
    raise "Can't instantiate class {{klass.id}}"
  end
end