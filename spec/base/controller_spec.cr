require "./spec_helper"

describe Base::Controller do

  describe "#initialize" do
    controller = create_controller_instance(IndexController) 

    it "adds actions to @actions hash as procs" do
      controller.actions.should be_a Hash
      controller.actions.length.should eq 3
      controller.actions["hello"].should eq ->controller.hello
      controller.actions["bye"].should be_a Proc(Void)
    end
  end


  describe "#call_action" do
    controller = create_controller_instance(IndexController) 

    it "should raise exception if action not found" do
      expect_raises ControllerActionNotFound do
        controller.call_action "hell"
      end
    end

    it "should return Http::Response" do
      controller.call_action "hello"
      controller.response.should be_a Http::Response
      controller.response.body.should eq "Hello"
      controller.response.status.should eq 200

      controller.call_action("bye")
      controller.response.should be_a Http::Response
      controller.response.status.should eq 200
      controller.response.body.should eq "Bye"
    end
  end


  describe "#respond_to" do
    controller = create_controller_instance(ViewController)

    it "raises HttpBadRequest exception if request not processed" do
      controller.request.header "Accept", "image/jpg"
      expect_raises HttpBadRequest do
        controller.respond_to do |format|
          format.html {}
        end
      end
    end
    
    # TODO : Move theese to integration tests
    it "can renders view in block" do
      controller.request.header "Accept", "text/html"
      controller.call_action "hello"
      controller.response.body.should eq "Hello, Andrew"
    end

    it "can redirect in block" do
      controller.call_action "redirect"
      controller.response.status.should eq 303
    end
  end


  describe Base::Controller::Formatter do

    describe "#html" do
      request, response = HttpHlp.get_env

      it "yields to the block if request.accept is 'text/html'" do
        request.headers["Accept"] = "text/html"
        formatter = Base::Controller::Formatter.new(request, response)
        formatter.html {}
        formatter.processed.should eq true

        request.headers["Accept"] = "text/plain"
        formatter = Base::Controller::Formatter.new(request, response)
        formatter.html {}
        formatter.processed.should eq false
      end
    end


    describe "#any" do
      request, response = HttpHlp.get_env

      it "yields to the block regardless of value of request.accept" do
        request.headers["Accept"] = "text/html"
        formatter = Base::Controller::Formatter.new(request, response)
        formatter.any {}
        formatter.processed.should eq true

        request.headers["Accept"] = "text/plain"
        formatter = Base::Controller::Formatter.new(request, response)
        formatter.any {}
        formatter.processed.should eq true
      end
    end
  end
end