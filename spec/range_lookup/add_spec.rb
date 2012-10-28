require 'spec_helper'

describe "Range Lookup: Adding" do

  def state
    ranges = {}
    redis.zrange('my_store:~', 0, -1, with_scores: true).each do |value, score|
      ranges[score.to_f] = redis.smembers("my_store:#{value}").sort.join
    end
    ranges
  end

  def add(member, min, max)
    evalsha :add, keys: ["my_store"], argv: [member, min, max]
  end

  before { add("A", 8, 17) }

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

  it 'should support single-value ranges' do
    lambda { add("B", 10, 10) }.should change { state }.
      to 8.0 => "A", 10.0 => "AB", 17.0 => "A"
  end

  it 'should support float/decimal ranges' do
    lambda { add("B", 10, 10.5) }.should change { state }.
      to 8.0 => "A", 10.0 => "AB", 10.5 => "AB", 17.0 => "A"
  end

  it 'should support zero bounds' do
    lambda { add("B", 0, 5) }.should change { state }.
      to 0.0 => "B", 5.0 => "B", 8.0 => "A", 17.0 => "A"

    lambda { add("C", -5, 0) }.should change { state }.
      to -5.0 => "C", 0.0 => "BC", 5.0 => "B", 8.0 => "A", 17.0 => "A"
  end

  it 'should maintain an index' do
    redis.zrange('my_store:~', 0, -1, with_scores: true).should == [["8", 8.0], ["17", 17.0]]
  end

  it 'should store range values' do
    redis.keys.should =~ ["my_store:~", "my_store:8", "my_store:17"]
    state.should == { 8.0 => "A", 17.0 => "A" }
  end

  it 'should return OK if successful' do
    add("B", 9, 18).should == "OK"
  end

  it 'should add non overlapping, left (B B A A)' do
    lambda { add("B", 5, 6) }.should change { state }.
      to 5.0 => "B", 6.0 => "B", 8.0 => "A", 17.0 => "A"
  end

  it 'should add non overlapping, right (A A B B)' do
    lambda { add("B", 18, 23) }.should change { state }.
      to 8.0 => "A", 17.0 => "A", 18.0 => "B", 23.0 => "B"
  end

  it 'should add non overlapping, inner (A B B A)' do
    lambda { add("B", 9, 12) }.should change { state }.
      to 8.0 => "A", 9.0 => "AB", 12.0 => "AB", 17.0 => "A"
  end

  it 'should add overlapping, left (B A B A)' do
    lambda { add("B", 6, 10) }.should change { state }.
      to 6.0 => "B", 8.0 => "AB", 10.0 => "AB", 17.0 => "A"
  end

  it 'should add overlapping, right (A B A B)' do
    lambda { add("B", 15, 23) }.should change { state }.
      to 8.0 => "A", 15.0 => "AB", 17.0 => "AB", 23.0 => "B"
  end

  it 'should add overlapping, both (AB BA)' do
    lambda { add("B", 8, 17) }.should change { state }.
      to 8.0 => "AB", 17.0 => "AB"
  end

  it 'should add tangent, outer left (B BA A)' do
    lambda { add("B", 6, 8) }.should change { state }.
      to 6.0 => "B", 8.0 => "AB",  17.0 => "A"
  end

  it 'should add tangent, inner left (AB B A)' do
    lambda { add("B", 8, 10) }.should change { state }.
      to 8.0 => "AB", 10.0 => "AB",  17.0 => "A"
  end

  it 'should add tangent, outer right (A AB B)' do
    lambda { add("B", 17, 22) }.should change { state }.
      to 8.0 => "A", 17.0 => "AB", 22.0 => "B"
  end

  it 'should add tangent, inner right (A B BA)' do
    lambda { add("B", 12, 17) }.should change { state }.
      to 8.0 => "A", 12.0 => "AB", 17.0 => "AB"
  end

  it 'should bring it all together' do
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
       5.0 => "B",       6.0 => "BEH",     7.0 => "EHJ",
       8.0 => "AEGHIJ",  9.0 => "ADEGIJ", 10.0 => "ADEGIJ",
      12.0 => "ADGJK",  15.0 => "AFGJK",  17.0 => "AFGJK",
      18.0 => "CFJ",    22.0 => "CFJ",    23.0 => "CF"
    }
  end

end
