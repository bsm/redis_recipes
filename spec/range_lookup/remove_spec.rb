require 'spec_helper'

describe "Range Lookup: Removing" do

  def state
    ranges = {}
    redis.zrange('my_store:~', 0, -1, with_scores: true).each do |value, score|
      ranges[score.to_f] = redis.smembers("my_store:#{value}").sort.join
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

  before { add("A", 8, 17) }

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

  it 'should return OK if successful' do
    remove("A", 8, 17).should == "OK"
    state.should == {}
  end

  it 'should support zero bounds' do
    add("B", -5, 0)
    add("C", 0, 5)

    lambda {
      remove("B", -5, 0)
      remove("C", 0, 5)
    }.should change { state }.
      from(-5.0 => "B", 0.0 => "BC", 5.0 => "C", 8.0 => "A", 17.0 => "A").
      to(8.0 => "A", 17.0 => "A")
  end

  it 'should clean up index' do
    lambda {
      add("B", 15, 22)
      add("C", 15, 23)
    }.should change { brackets }.to ["8", "15", "17", "22", "23"]

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

  it 'should remove non overlapping segments' do
    lambda {
      add("B", 5, 6)
      add("C", 18, 23)
    }.should change { state }.
      to 5.0=>"B", 6.0=>"B", 8.0=>"A", 17.0=>"A", 18.0=>"C", 23.0=>"C"

    lambda { remove("B", 5, 6) }.should change { state }.
      to 8.0 => "A", 17.0 => "A", 18.0 => "C", 23.0 => "C"

    lambda { remove("C", 18, 23) }.should change { state }.
      to 8.0 => "A", 17.0 => "A"
  end

  it 'should remove overlapping segments' do
    lambda {
      add("B", 6, 10)
      add("C", 9, 12)
      add("D", 15, 23)
    }.should change { state }.
      to 6.0=>"B", 8.0=>"AB", 9.0=>"ABC", 10.0=>"ABC", 12.0=>"AC", 15.0 => "AD", 17.0 => "AD", 23.0 => "D"

    lambda { remove("B", 6, 10) }.should change { state }.
      to 8.0 => "A", 9.0 => "AC", 12.0 => "AC", 15.0 => "AD", 17.0 => "AD", 23.0 => "D"

    lambda { remove("C", 9, 12) }.should change { state }.
      to 8.0 => "A", 15.0 => "AD", 17.0 => "AD", 23.0 => "D"

    lambda { remove("D", 15, 23) }.should change { state }.
      to 8.0 => "A", 17.0 => "A"
  end

  it 'should remove tangent segments' do
    lambda {
      add("B", 6, 8)
      add("C", 17, 23)
      add("D", 8, 17)
    }.should change { state }.
      to 6.0 => "B", 8.0 => "ABD", 17.0 => "ACD", 23.0 => "C"

    lambda { remove("B", 6, 8) }.should change { state }.
      to 8.0 => "AD", 17.0 => "ACD", 23.0 => "C"

    lambda { remove("C", 17, 23) }.should change { state }.
      to 8.0 => "AD", 17.0 => "AD"

    lambda { remove("D", 8, 17) }.should change { state }.
      to 8.0 => "A", 17.0 => "A"
  end
end
