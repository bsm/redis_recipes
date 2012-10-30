require 'spec_helper'

describe "Range Lookup X: Removing" do

  def state(c = :to_i)
    ranges = {}
    redis.zrange('my_store:~', 0, -1, with_scores: true).each do |value, score|
      ranges[score.send(c)] = redis.smembers("my_store:#{value}").sort.join
    end
    ranges
  end

  def brackets
    redis.zrange('my_store:~', 0, -1)
  end

  def add(member, min, max)
    evalsha :add, keys: ["my_store"], argv: [member, min, max]
  end

  def remove(member, min, max)
    evalsha :remove, keys: ["my_store"], argv: [member, min, max]
  end

  def scenario(pairs)
    pairs.each do |member, range|
      add member.to_s, range.first, range.last
    end
  end

  describe "general" do

    it 'should catch invalid arguments' do
      lambda { evalsha :remove }.should raise_error(Redis::CommandError, /wrong number of arguments/)
      lambda { evalsha :remove, keys: ["one"] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
      lambda { evalsha :remove, keys: ["one"], argv: ["one", 2] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
      lambda { evalsha :remove, keys: ["one", "two"], argv: ["one", 2, 3] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
    end

    it 'should catch non-numeric ranges' do
      lambda { evalsha :remove, keys: ["one"], argv: ["one", "two", 3] }.should raise_error(Redis::CommandError, /not numeric or out of range/)
      lambda { evalsha :remove, keys: ["one"], argv: ["one", 2, "three"] }.should raise_error(Redis::CommandError, /not numeric or out of range/)
      lambda { evalsha :remove, keys: ["one"], argv: ["one", 3, 2] }.should raise_error(Redis::CommandError, /not numeric or out of range/)
    end

  end

  describe "removing" do
    before { add("A", 8, 17) }
    
    it 'should return OK if successful' do  
      remove("A", 8, 17).should == "OK"
    end

    it 'should support negative ranges & zero bounds' do
      scenario B: -5..0, C: 0..5

      lambda {
        remove("B", -5, 0)
        remove("C",  0, 5)
      }.should change { state }.
        from(-5 => "B", 0 => "C", 5 => "", 8 => "A", 17 => "").
        to(8 => "A", 17 => "")
    end

    it 'should clean up index' do
      scenario B: 15..22, C: 15..23

      lambda {
        remove("B", 15, 22)
      }.should change { brackets }.to ["8", "15", "17", "23"]

      lambda {
        remove("C", 15, 23)
      }.should change { brackets }.to ["8", "17"]

      lambda {
        remove("A", 8, 17)
      }.should change { brackets }.to []
    end

  end

  describe "use cases" do

    it "should remove from [A: 1-2, B: 3-4]" do
      scenario A: 1..2, B: 3..4
      lambda { remove("A", 1, 2) }.should change { state }.
        from(1 => "A", 2 => "", 3 => "B", 4 => "").
        to(3 => "B", 4 => "")
    end

    it "should remove from [A: 3-4, B: 1-2]" do      
      scenario A: 3..4, B: 1..2
      lambda { remove("A", 3, 4) }.should change { state }.
        from(1 => "B", 2 => "", 3 => "A", 4 => "").
        to(1 => "B", 2 => "")
    end

    it "should remove from [A: 1-3, B: 2-4]" do
      scenario A: 1..3, B: 2..4
      lambda { remove("A", 1, 3) }.should change { state }.
        from(1 => "A", 2 => "AB", 3 => "B", 4 => "").
        to(2 => "B", 4 => "")
    end

    it "should remove from [A: 2-4, B: 1-3]" do
      scenario A: 2..4, B: 1..3
      lambda { remove("A", 2, 4) }.should change { state }.
        from(1 => "B", 2 => "AB", 3 => "A", 4 => "").
        to(1 => "B", 3 => "")
    end

    it "should remove from [A: 1-4, B: 2-3]" do
      scenario A: 1..4, B: 2..3
      lambda { remove("A", 1, 4) }.should change { state }.
        from(1 => "A", 2 => "AB", 3 => "A", 4 => "").
        to(2 => "B", 3 => "")
    end

    it "should remove from [A: 2-3, B: 1-4]" do
      scenario A: 2..3, B: 1..4
      lambda { remove("A", 2, 3) }.should change { state }.
        from(1 => "B", 2 => "AB", 3 => "B", 4 => "").
        to(1 => "B", 4 => "")
    end

    it "should remove from [A: 1-3, B: 3-4]" do
      scenario A: 1..3, B: 3..4
      lambda { remove("A", 1, 3) }.should change { state }.
        from(1 => "A", 3 => "B", 4 => "").
        to(3 => "B", 4 => "")
    end

    it "should remove from [A: 1-4, B: 3-4]" do
      scenario A: 1..4, B: 3..4
      lambda { remove("A", 1, 4) }.should change { state }.
        from(1 => "A", 3 => "AB", 4 => "").
        to(3 => "B", 4 => "")
    end

    it "should remove from [A: 3-4, B: 1-3]" do
      scenario A: 3..4, B: 1..3
      lambda { remove("A", 3, 4) }.should change { state }.
        from(1 => "B", 3 => "A", 4 => "").
        to(1 => "B", 3 => "")
    end

    it "should remove from [A: 3-4, B: 1-4]" do
      scenario A: 3..4, B: 1..4
      lambda { remove("A", 3, 4) }.should change { state }.
        from(1 => "B", 3 => "AB", 4 => "").
        to(1 => "B", 4 => "")
    end

    it "should remove from [A: 1-4, B: 1-2]" do
      scenario A: 1..4, B: 1..2
      lambda { remove("A", 1, 4) }.should change { state }.
        from(1 => "AB", 2 => "A", 4 => "").
        to(1 => "B", 2 => "")
    end

    it "should remove from [A: 2-4, B: 1-2]" do
      scenario A: 2..4, B: 1..2
      lambda { remove("A", 2, 4) }.should change { state }.
        from(1 => "B", 2 => "A", 4 => "").
        to(1 => "B", 2 => "")
    end

    it "should remove from [A: 1-4, B: 1-4]" do
      scenario A: 1..4, B: 1..4
      lambda { remove("A", 1, 4) }.should change { state }.
        from(1 => "AB", 4 => "").
        to(1 => "B", 4 => "")
    end

    it "should remove from [A: 1-4]" do
      scenario A: 1..4
      lambda { remove("A", 1, 4) }.should change { state }.
        from(1 => "A", 4 => "").
        to({})
    end

  end

end
