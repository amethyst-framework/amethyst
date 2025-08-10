require "./spec_helper"

describe "Amethyst Modern Framework" do
  describe "basic instantiation" do
    it "can create application instances" do
      app = Amethyst::Application.new("development")
      app.should be_a(Amethyst::Application)
    end
    
    it "supports different environments" do
      dev_app = Amethyst::Application.new("development")  
      prod_app = Amethyst::Application.new("production")
      test_app = Amethyst::Application.new("test")
      
      dev_app.should be_a(Amethyst::Application)
      prod_app.should be_a(Amethyst::Application)
      test_app.should be_a(Amethyst::Application)
    end
  end
  
  describe "configuration objects" do
    it "can create security config" do
      config = Amethyst::Config::SecurityConfig.new
      config.should be_a(Amethyst::Config::SecurityConfig)
    end
    
    it "can create performance config" do
      config = Amethyst::Config::PerformanceConfig.new
      config.should be_a(Amethyst::Config::PerformanceConfig)
    end
    
    it "can create observability config" do
      config = Amethyst::Config::ObservabilityConfig.new
      config.should be_a(Amethyst::Config::ObservabilityConfig)
    end
    
    it "can create realtime config" do
      config = Amethyst::Config::RealtimeConfig.new
      config.should be_a(Amethyst::Config::RealtimeConfig)
    end
  end
  
  describe "fluent configuration" do
    it "allows security configuration" do
      app = Amethyst::Application.new("test")
        .security { |s| s }
        
      app.should be_a(Amethyst::Application)
    end
    
    it "allows performance configuration" do
      app = Amethyst::Application.new("test")
        .performance { |p| p }
        
      app.should be_a(Amethyst::Application)
    end
    
    it "allows observability configuration" do
      app = Amethyst::Application.new("test")
        .observability { |o| o }
        
      app.should be_a(Amethyst::Application)
    end
    
    it "allows realtime configuration" do
      app = Amethyst::Application.new("test")
        .realtime { |r| r }
        
      app.should be_a(Amethyst::Application)
    end
  end
  
  describe "routing DSL" do
    it "allows adding GET routes" do
      app = Amethyst::Application.new("test")
        .get("/", "TestController", "index")
        
      app.should be_a(Amethyst::Application)
    end
    
    it "allows adding multiple route types" do
      app = Amethyst::Application.new("test")
        .get("/", "TestController", "index")
        .post("/users", "TestController", "create")  
        .put("/users/1", "TestController", "update")
        .delete("/users/1", "TestController", "destroy")
        
      app.should be_a(Amethyst::Application)
    end
  end
  
  describe "method chaining" do
    it "supports full fluent interface" do
      app = Amethyst::Application.new("production")
        .security { |s| s.csrf(enabled: true) }
        .performance { |p| p.caching(enabled: true) }
        .observability { |o| o.structured_logging(level: "info") }
        .realtime { |r| r.websockets(enabled: false) }
        .get("/", "TestController", "index")
        .get("/health", "TestController", "health")
        
      app.should be_a(Amethyst::Application)
    end
  end
end