require "./spec_helper"

module Amethyst
  module Http
    describe Request do
      describe "#initialize" do
        headers = HTTP::Headers.new
        headers["Accept"] = ["text/plain"]
        base_request = HTTP::Request.new("GET", "/", headers, "Test")
        request = Request.new(base_request)

        it "instantiate Request object properly" do
          request.method.should eq "GET"
          request.path.should eq "/"
          request.headers["Accept"].should eq "text/plain"
          request.body.as(IO).gets.should eq "Test"
          request.version.should eq "HTTP/1.1"
        end
      end

      describe "#get? #post? #put? delete?" do
        it "checks if http method is 'GET'" do
          request = HttpHlp.req("GET", "/")
          request.get?.should eq true
        end

        it "checks if http method is 'POST'" do
          request = HttpHlp.req("POST", "/")
          request.post?.should eq true
        end

        it "checks if http method is 'PUT'" do
          request = HttpHlp.req("PUT", "/")
          request.put?.should eq true
        end

        it "checks if http method is 'POST'" do
          request = HttpHlp.req("DELETE", "/")
          request.delete?.should eq true
        end

        it "checks if http method is not 'POST'" do
          request = HttpHlp.req("PUT", "/")
          request.get?.should eq false
        end
      end

      describe "#query_string" do
        it "returns query string, if exists" do
          request = HttpHlp.req("GET", "/index/path.html?p1=v1&p2=v2")
          request.query_string.should eq "p1=v1&p2=v2"
        end

        it "returns nil if query_string not presented" do
          request = HttpHlp.req("GET", "/index/")
          request.query_string.should eq nil
          request.path = "/index"
          request.query_string.should eq nil
        end
      end

      describe "#path" do
        it "returns path without query string" do
          request = HttpHlp.req("GET", "/index")
          request.path.should eq "/index"

          request = HttpHlp.req("GET", "/index?user_id=1")
          request.path.should eq "/index"
        end
      end

      describe "#query_parameters" do
        it "returns query (GET) parameters" do
          request = HttpHlp.req("GET", "/index?user=user&name=name")
          request.query_parameters.should eq Hash{"user" => "user", "name" => "name"}
        end
      end

      describe "#request_parameters" do
        it "returns request (POST) parameters" do
          request = HttpHlp.req("GET", "/")
          request.body = "user=Andrew&id=5"
          request.content_type = "application/x-www-form-urlencoded"
          request.request_parameters.should eq Hash{"user" => "Andrew", "id" => "5"}
        end
      end

      describe "#path_parameters" do
        it "returns path parameters" do
          request = HttpHlp.req("GET", "/users/55")
          App.routes.draw do
            get "/users/:id", "index#users"
            register IndexController
          end
          request.path_parameters.should eq Hash{"id" => "55"}
        end
      end

      describe "#accept" do
        it "returns 'text/html' if Accept header contains '*/*'" do
          request = HttpHlp.req("GET", "/users/55")
          accept_string = "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0"
          request.header "Accept", accept_string
          request.accept.should eq "text/html"
        end

        it "returns first mime-type if Accept doesn't contain '*/*" do
          request = HttpHlp.req("GET", "/users/55")
          accept_string = "application/xhtml+xml,application/xml;q=0.9,image/webp"
          request.header "Accept", accept_string
          request.accept.should eq "application/xhtml+xml"
        end
      end

      describe "#cookies" do
        it "parses 'Cookie' header and returns a cookie Params" do
          request = HttpHlp.req("GET", "/")
          request.headers.add "Cookie", "id=22; name=Amethyst"
          request.cookies["name"].should eq "Amethyst"
        end

        it "return empty Params if header 'Cookie' is not sended by browser" do
          request = HttpHlp.req("GET", "/")
          request.cookies["name"].should eq ""
          request.cookies.should be_a Http::Params
        end
      end

      describe "#parameters" do
        it "contains all parameters" do
          request = HttpHlp.req("GET", "/users/95?id=22&name=Amethyst&page=90")
          request.body = "user=Andrew&id=5"
          request.content_type = "application/x-www-form-urlencoded"
          App.routes.draw do
            get "/users/:id", "index#users"
            register IndexController
          end
          request.parameters.should eq Hash{"user" => "Andrew", "id" => "95", "name" => "Amethyst", "page" => "90"}
        end
      end

      describe "#parse_parameters" do
        it "sets parameter value to empty String if value is not set" do
          request = HttpHlp.req("GET", "/index?id=45&name=")
          request.request_parameters[:id].should eq ""
        end
      end
    end
  end
end
