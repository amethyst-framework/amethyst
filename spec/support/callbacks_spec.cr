require "./spec_helper"

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