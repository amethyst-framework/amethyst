require "../spec_helper"

describe "Amethyst Config System" do
  describe "SecurityConfig" do
    it "can be instantiated" do
      config = Amethyst::Config::SecurityConfig.new
      config.should be_a(Amethyst::Config::SecurityConfig)
    end
    
    it "has environment presets" do
      dev_config = Amethyst::Config::SecurityConfig.development
      prod_config = Amethyst::Config::SecurityConfig.production
      test_config = Amethyst::Config::SecurityConfig.testing
      
      dev_config.should be_a(Amethyst::Config::SecurityConfig)
      prod_config.should be_a(Amethyst::Config::SecurityConfig)
      test_config.should be_a(Amethyst::Config::SecurityConfig)
    end
    
    it "supports fluent configuration" do
      config = Amethyst::Config::SecurityConfig.new
        .csrf(enabled: false)
        .xss_protection(enabled: true)
        .rate_limiting(enabled: true)
        
      config.should be_a(Amethyst::Config::SecurityConfig)
    end
  end
  
  describe "PerformanceConfig" do
    it "can be instantiated" do
      config = Amethyst::Config::PerformanceConfig.new
      config.should be_a(Amethyst::Config::PerformanceConfig)
    end
    
    it "has environment presets" do
      dev_config = Amethyst::Config::PerformanceConfig.development
      prod_config = Amethyst::Config::PerformanceConfig.production
      test_config = Amethyst::Config::PerformanceConfig.testing
      
      dev_config.should be_a(Amethyst::Config::PerformanceConfig)
      prod_config.should be_a(Amethyst::Config::PerformanceConfig)  
      test_config.should be_a(Amethyst::Config::PerformanceConfig)
    end
    
    it "supports fluent configuration" do
      config = Amethyst::Config::PerformanceConfig.new
        .caching(enabled: true)
        .static_files(gzip: false)
        .connection_pooling(max_connections: 10)
        
      config.should be_a(Amethyst::Config::PerformanceConfig)
    end
  end
  
  describe "ObservabilityConfig" do
    it "can be instantiated" do
      config = Amethyst::Config::ObservabilityConfig.new
      config.should be_a(Amethyst::Config::ObservabilityConfig)
    end
    
    it "has environment presets" do
      dev_config = Amethyst::Config::ObservabilityConfig.development
      prod_config = Amethyst::Config::ObservabilityConfig.production
      test_config = Amethyst::Config::ObservabilityConfig.testing
      
      dev_config.should be_a(Amethyst::Config::ObservabilityConfig)
      prod_config.should be_a(Amethyst::Config::ObservabilityConfig)
      test_config.should be_a(Amethyst::Config::ObservabilityConfig)
    end
    
    it "supports fluent configuration" do
      config = Amethyst::Config::ObservabilityConfig.new
        .structured_logging(level: "info")
        .health_checks(enabled: true)
        .metrics(enabled: false)
        
      config.should be_a(Amethyst::Config::ObservabilityConfig)
    end
  end
  
  describe "RealtimeConfig" do
    it "can be instantiated" do
      config = Amethyst::Config::RealtimeConfig.new
      config.should be_a(Amethyst::Config::RealtimeConfig)
    end
    
    it "has environment presets" do
      dev_config = Amethyst::Config::RealtimeConfig.development
      prod_config = Amethyst::Config::RealtimeConfig.production
      test_config = Amethyst::Config::RealtimeConfig.testing
      
      dev_config.should be_a(Amethyst::Config::RealtimeConfig)
      prod_config.should be_a(Amethyst::Config::RealtimeConfig)
      test_config.should be_a(Amethyst::Config::RealtimeConfig)
    end
    
    it "supports fluent configuration" do
      config = Amethyst::Config::RealtimeConfig.new
        .websockets(enabled: true)
        .server_sent_events(enabled: false)
        .authentication(enabled: true)
        
      config.should be_a(Amethyst::Config::RealtimeConfig)
    end
  end
end