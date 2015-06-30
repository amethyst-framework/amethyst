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

class Pool
  property :pool

  def initialize
    @pool = {} of String => Hash
  end

  def generate_sid(cookie="")
    sid = loop do
      sid = Base64.urlsafe_encode64(SecureRandom.random_bytes(128))
      break sid unless @pool.has_key?(sid)
    end
    @pool[sid] = {cookie: cookie.to_s}
    sid
  end

  def get_session(sid)
    if @pool.has_key?(sid.to_s)
      @pool[sid.to_s]
    else
      sid = generate_sid
      @pool[sid]
    end
  end

  def destroy_session(sid)
    if @pool.has_key?(sid.to_s)
      @pool.delete(sid.to_s)
    end
  end

end
