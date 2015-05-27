class BaseController
  
  def initialize()
    @controllers = {} of String => Proc
    actions
  end
  
  def call_action(action, request)
    @controllers.fetch(action).call(request)
  end
  
  #def say(request)
    #puts "say #{@i}"
  #end
  
  #def bye(request)
    #puts "bye"
  #end
  
  macro add_to_hash(action)
      @controllers[{{action}}.to_s] = ->{{action.id}}(String)
  end

  def actions
    add :say
    add :bye
  end
end

#controller = Controller.new
#controller.call_action("bye", "request")
#controller.call_action("say", "request")