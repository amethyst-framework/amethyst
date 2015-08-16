# Part of the Seesion module Session::Pool
# Example
#
# initialize pool:
# session_pool = Pool.new
#
# Get a session ID:
# session_id = session_pool.generate_sid
#
# Populate with some info:
# session_pool.pool[session_id][:cookie] = "new_cookie"
# session_pool.pool[session_id][:username] = "admin"
# session_pool.pool[session_id][:password] = "secret"
#
# Get the session details:
# session_pool.get_session(session_id)
require "secure_random"

class Pool
  property :pool

  include Sugar::Klass
  singleton_INSTANCE

  def initialize
    @pool = {} of String => Hash
  end

  def generate_sid
    sid = loop do
      sid = Base64.urlsafe_encode(SecureRandom.random_bytes(128))
      break sid unless @pool.has_key?(sid)
    end
    @pool[sid] = {} of Symbol => String
    sid
  end

  def get_session(sid)
    if @pool.has_key?(sid)
      @pool[sid]
    else
      @pool[sid] = {} of Symbol => String
    end
  end

  def destroy_session(sid)
    if @pool.has_key?(sid)
      @pool.delete(sid)
    end
  end

end
