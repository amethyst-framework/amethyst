class Config
  property :environment
  property :app_dir

  # Simple configuration class for App
  
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