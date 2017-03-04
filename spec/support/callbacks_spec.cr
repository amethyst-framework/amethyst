require "./spec_helper"

class CallbacksDefineTest
  getter test_before
  getter test_after

  include Callbacks
  define_callbacks :first, :second
  set_callback :first, :before, :before_method
  set_callback :first, :after, :after_method

  def callback
    run_callbacks :first do
      "callback"
    end
  end

  def before_method
    @test_before = (5+8).as(Int32)
    true
  end

  def after_method
    @test_after = (6+9).as(Int32)
    true
  end
end

describe Support::Callbacks::CallbackSequence do

  describe "#after #before" do
    callback_sequence = Callbacks::CallbackSequence.new
    it "adds proc to array and returns CallbackSequence object" do
      callback_sequence.before(->{ 1; true }).before(->{ 2; true })
      callback_sequence.length.should eq 2

      callback_sequence.after(->{ false }).after(->{ false })
      callback_sequence.length.should eq 4
    end
  end


  describe "#call" do

    it "calls callbacks and returns true if all callbacks returns true" do
      callback_sequence = Callbacks::CallbackSequence.new
      callback_sequence.before(->{ 1; true }).before(->{ 2; true })
      callback_sequence.after(->{ 1; true }).after(->{ 2; true })
      result = callback_sequence.call { "Done" }
      result.should eq "Done"
    end

    it "calls callbacks and returns false if at least one callback returns false" do
      callback_sequence = Callbacks::CallbackSequence.new
      callback_sequence.before(->{ 1; true }).before(->{ 2; true })
      callback_sequence.after(->{ 1; false }).after(->{ 2; true })
      result = callback_sequence.call {}
      result.should eq false
    end
  end
end

describe "macro define_callbacks" do
  it "should create method that returns CallbackSequence" do
    callback_sequence = CallbacksDefineTest.new
    callback_sequence._first_callbacks.should be_a Callbacks::CallbackSequence
    callback_sequence._second_callbacks.should be_a Callbacks::CallbackSequence
  end
end

describe "macro set_callbacks" do
  callback_sequence = CallbacksDefineTest.new

  it "should create instance method that add callback to CallbackSequence" do
    callback_sequence.responds_to?(:_set_first_before_before_method).should eq true
  end

  it "created instance method adds callback to CallbackSequence" do
    callback_sequence._set_first_before_before_method
    callback_sequence._first_callbacks.length.should eq 1
  end
end

describe "macro run_callbacks" do
  callback_sequence = CallbacksDefineTest.new
  response = callback_sequence.callback

  it "should run added callbacks" do
    callback_sequence.test_before.should eq 13
    callback_sequence.test_after.should eq 15
  end

  it "should return block value" do
    response.should eq "callback"
  end
end
