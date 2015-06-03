class Config

  # Config class is storage of :key => "value"
  # You can get and set values by invoking config.key value
  # All values will be transformed to strings through to_s
  
  include Sugar
  singleton_INSTANCE

  def initialize
    @config = {} of Symbol => String
    set_defaults
  end

  macro method_missing(name, args, block)
    {% if args[0] == nil %}
      begin
        return @config[:{{name}}]
      rescue e
        raise "No config key with name :{{name.id}}"
        return
      end
    {% else %}
        @config[:{{name.id}}] = {{args[0]}}.to_s
    {% end %}
  end

  # Sets default configuration
  def set_defaults
    environment "production"
  end

  # Configures application with given block
  def configure(&block)
    with self yield self 
  end
end