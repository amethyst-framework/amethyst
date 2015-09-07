require "./spec_helper"

describe Pool do

  session_pool = Pool::INSTANCE

  describe "#generate_sid" do
    it "should return a unique id" do
      sid = session_pool.generate_sid
      sid.should be_a String
    end
  end

  describe "#get_session" do
    it "should return a session hash" do
      sid = session_pool.generate_sid
      session_pool.get_session(sid).should be_a Hash(Symbol, String)
    end

    it "should return the value saved in the session by key" do
      sid = session_pool.generate_sid
      session = session_pool.get_session(sid)
      session[:test] = "Test"
      session2 = session_pool.get_session(sid)
      session2[:test].should be "Test"
    end
  end

  describe "#destroy_session" do
    it "should destroy the session hash" do
      sid = session_pool.generate_sid
      session_pool.get_session(sid)[:test] = "Test"
      session_pool.destroy_session(sid)
      expect_raises(KeyError) do
        session_pool.get_session(sid)[:test]
      end
    end
  end
end
