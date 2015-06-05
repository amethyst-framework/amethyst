class Config
  property :environment
  property :app_dir

  # Config class is storage of :key => "value"
  # You can get and set values by invoking config.key value
  # All values will be transformed to strings through to_s
  
  include Sugar
  singleton_INSTANCE

  def initialize
    @enviroment  = "production"
    @app_dir     = ""
  end
  
  def self.configure(&block)
    yield INSTANCE
  end

  # Configures application with given block
  def configure(&block)
    with self yield self 
  end
end