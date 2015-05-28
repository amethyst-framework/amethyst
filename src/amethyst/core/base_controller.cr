class BaseController
  getter :actions_hash
  
  def initialize()
    @actions_hash = {} of String => Proc
    actions
  end
  
  def call_action(action, request)
    @actions_hash.fetch(action).call(request)
  end
  
  macro add(action)
    @actions_hash[{{action}}.to_s] = ->{{action.id}}(String)
  end

  def actions
  end
end