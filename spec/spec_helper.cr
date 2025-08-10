require "spec"
require "../src/amethyst"

# Test helper for creating mock HTTP requests
class MockRequest
  getter method : String
  getter path : String
  getter headers : Hash(String, String)
  getter body : String?
  
  def initialize(@method : String, @path : String, @headers = {} of String => String, @body : String? = nil)
  end
  
  def self.get(path : String, headers = {} of String => String)
    new("GET", path, headers)
  end
  
  def self.post(path : String, body : String? = nil, headers = {} of String => String)
    new("POST", path, headers, body)
  end
  
  def self.put(path : String, body : String? = nil, headers = {} of String => String)
    new("PUT", path, headers, body)
  end
  
  def self.delete(path : String, headers = {} of String => String)
    new("DELETE", path, headers)
  end
end

# Test helper for creating mock HTTP responses  
class MockResponse
  property status : Int32
  property body : String
  property headers : Hash(String, String)
  
  def initialize(@status : Int32 = 200, @body : String = "", @headers = {} of String => String)
  end
  
  def status_code
    @status
  end
end

# Test controller for route testing
class TestController < Amethyst::Controller
  def index
    "Hello from index"
  end
  
  def show
    "Hello from show: #{params["id"]?}"
  end
  
  def create
    "Created successfully"
  end
  
  def health
    "OK"
  end
end

# Mock middleware for testing
class TestMiddleware
  def initialize(@name : String)
  end
  
  def call(context)
    context.response.headers["X-Test-Middleware"] = @name
    context
  end
end