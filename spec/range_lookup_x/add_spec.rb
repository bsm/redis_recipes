require 'spec_helper'

describe "Range Lookup X: Adding" do

  def state(c = :to_i)
    ranges = {}
    redis.zrange('my_store:~', 0, -1, with_scores: true).each do |value, score|
      ranges[score.send(c)] = redis.smembers("my_store:#{value}").sort.join
    end
    ranges
  end

  def add(member, min, max)
    evalsha :add, keys: ["my_store"], argv: [member, min, max]
  end

  describe "general" do
  
    it 'should catch invalid arguments' do
      lambda { evalsha :add }.should raise_error(Redis::CommandError, /wrong number of arguments/)
      lambda { evalsha :add, keys: ["one"] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
      lambda { evalsha :add, keys: ["one"], argv: ["one", 2] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
      lambda { evalsha :add, keys: ["one", "two"], argv: ["one", 2, 3] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
    end

    it 'should catch non-numeric ranges' do
      lambda { evalsha :add, keys: ["one"], argv: ["one", "two", 3] }.should raise_error(Redis::CommandError, /not numeric or out of range/)
      lambda { evalsha :add, keys: ["one"], argv: ["one", 2, "three"] }.should raise_error(Redis::CommandError, /not numeric or out of range/)
      lambda { evalsha :add, keys: ["one"], argv: ["one", 3, 2] }.should raise_error(Redis::CommandError, /not numeric or out of range/)
    end

    it 'should NOT support single-value ranges' do
      lambda { add("B", 10, 10) }.should raise_error(Redis::CommandError, /not numeric or out of range/)
    end

  end

  describe "adding" do

    it 'should store ranges' do      
      lambda { add("A", 8, 17) }.should change { state }.
        to 8 => "A", 17 => ""
    end

    it 'should support float/decimal ranges' do      
      lambda { add("A", 7.5, 17.9); add("B", 8.1, 10.6) }.should change { state(:to_f) }.
        to 7.5 => "A", 8.1 => "AB", 10.6 => "A", 17.9 => ""
    end

    it 'should support nagative ranges and bounds' do
      lambda { add("B", 0, 5) }.should change { state }.
        to 0 => "B", 5 => ""

      lambda { add("C", -5, 0) }.should change { state }.
        to -5 => "C", 0 => "B", 5 => ""
    end

    it 'should maintain an index' do
      lambda { add("A", 8, 17) }.should change { 
        redis.zrange('my_store:~', 0, -1, with_scores: true)
      }.to [["8", 8.0], ["17", 17.0]]
    end

    it 'should store range members' do
      lambda { add("A", 8, 17) }.should change { redis.keys.sort }.
        to ["my_store:8", "my_store:~"]
    end

    it 'should return OK if successful' do
      add("A", 8, 17).should == "OK"
    end

  end

  describe "merging" do
    before { add("A", 8, 17) }

    it 'should add non overlapping, left (B B A A)' do
      lambda { add("B", 5, 6) }.should change { state }.
        to 5 => "B", 6 => "", 8 => "A", 17 => ""
    end

    it 'should add non overlapping, right (A A B B)' do
      lambda { add("B", 18, 23) }.should change { state }.
        to 8 => "A", 17 => "", 18 => "B", 23 => ""
    end

    it 'should add non overlapping, inner (A B B A)' do
      lambda { add("B", 9, 12) }.should change { state }.
        to 8 => "A", 9 => "AB", 12 => "A", 17 => ""
    end

    it 'should add overlapping, left (B A B A)' do
      lambda { add("B", 6, 10) }.should change { state }.
        to 6 => "B", 8 => "AB", 10 => "A", 17 => ""
    end

    it 'should add overlapping, right (A B A B)' do
      lambda { add("B", 15, 23) }.should change { state }.
        to 8 => "A", 15 => "AB", 17 => "B", 23 => ""
    end

    it 'should add overlapping, both (AB BA)' do
      lambda { add("B", 8, 17) }.should change { state }.
        to 8 => "AB", 17 => ""
    end

    it 'should add tangent, outer left (B BA A)' do
      lambda { add("B", 6, 8) }.should change { state }.
        to 6 => "B", 8 => "A",  17 => ""
    end

    it 'should add tangent, inner left (AB B A)' do
      lambda { add("B", 8, 10) }.should change { state }.
        to 8 => "AB", 10 => "A",  17 => ""
    end

    it 'should add tangent, outer right (A AB B)' do
      lambda { add("B", 17, 22) }.should change { state }.
        to 8 => "A", 17 => "B", 22 => ""
    end

    it 'should add tangent, inner right (A B BA)' do
      lambda { add("B", 12, 17) }.should change { state }.
        to 8 => "A", 12 => "AB", 17 => ""
    end

    it 'should work with multiple ranges' do
      add("B",  5,  6)
      add("C", 18, 23)
      add("D",  9, 12)
      add("E",  6, 10)
      add("F", 15, 23)
      add("G",  8, 17)
      add("H",  6,  8)
      add("I",  8, 10)
      add("J",  7, 22)
      add("K", 12, 17)

      state.should == {
         5 => "B",       6 => "EH",      7 => "EHJ",
         8 => "AEGIJ",   9 => "ADEGIJ", 10 => "ADGJ",
        12 => "AGJK",   15 => "AFGJK",  17 => "FJ",
        18 => "CFJ",    22 => "CF",     23 => ""
      }
    end
  end

end
