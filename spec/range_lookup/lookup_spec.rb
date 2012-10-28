require 'spec_helper'

describe "Range Lookup: Lookup" do

  def add(member, min, max)
    evalsha :add, keys: ["my_store"], argv: [member, min, max]
  end

  def lookup(value)
    evalsha :lookup, keys: ["my_store"], argv: [value]
  end

  before do
    add("A", 0, 8)
    add("B", 4, 6)
    add("C", 2, 9)
    add("D", 7, 10)
  end

  def state
    ranges = {}
    redis.zrange('my_store:~', 0, -1, with_scores: true).each do |value, score|
      ranges[score.to_f] = redis.smembers("my_store:#{value}").sort
    end
    ranges
  end

  it 'should catch invalid arguments' do
    lambda { evalsha :lookup }.should raise_error(Redis::CommandError, /wrong number of arguments/)
    lambda { evalsha :lookup, keys: ["one"] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
    lambda { evalsha :lookup, keys: ["one"], argv: ["one", 2] }.should raise_error(Redis::CommandError, /wrong number of arguments/)
  end

  it 'should catch non-numeric ranges' do
    lambda { evalsha :lookup, keys: ["one"], argv: ["one"] }.should raise_error(Redis::CommandError, /not numeric or out of range/)
  end

  it 'should return the members when found' do
    lookup(0).should  =~ ["A"]
    lookup(1).should  =~ ["A"]
    lookup(2).should  =~ ["A", "C"]
    lookup(3).should  =~ ["A", "C"]
    lookup(4).should  =~ ["A", "B", "C"]
    lookup(5).should  =~ ["A", "B", "C"]
    lookup(6).should  =~ ["A", "B", "C"]
    lookup(7).should  =~ ["A", "C", "D"]
    lookup(8).should  =~ ["A", "C", "D"]
    lookup(9).should  =~ ["C", "D"]
    lookup(10).should =~ ["D"]
  end

  it 'should return an empty set if not found' do
    lookup(-1).should  =~ []
    lookup(11).should  =~ []
    lookup(111).should  =~ []
  end

  it 'should support float lookups' do
    lookup(6.5).should  =~ ["A", "C"]
    lookup(7.5).should  =~ ["A", "C", "D"]
    lookup(10.1).should =~ []
  end

end
