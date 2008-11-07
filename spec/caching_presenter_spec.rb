require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

class SingleObjectPresenter < CachingPresenter
  presents :foo

  delegate :raise_your_hand, :to => :@foo

  def stop!
    @foo.stop
  end

  def last_day?
    @foo.last_day
  end
  
  def talk(&blk)
    if block_given?
      yield @foo
    else
      @foo.speak
    end
  end
  
  def run(*args)
    @foo.run *args
  end
end

class SingleObjectWithConstructorRequirementsPresenter < CachingPresenter
  presents :foo, :requiring => [:bar, :baz]

  def sum
    @bar.amount + @baz.amount
  end
end

class FirstBarPresenter < CachingPresenter
  presents :bar

  def say(what) 
    @bar.say(what)
  end
end

class SecondBarPresenter < CachingPresenter
  presents :bar

  def say(what) 
    @bar.say(what)
  end
end

class ArrayPresenter < CachingPresenter
  presents :arr
end

describe CachingPresenter do
  it "it automatically delegates methods that exist on the object being presented" do
    foo = mock("foo")
    foo.should_receive(:amount).and_return 10
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.amount.should == 10
  end
  
  it "can present on an object with additional constructor requirements" do
    foo, bar, baz = mock("foo"), mock("bar"), mock("baz")
    bar.should_receive(:amount).and_return 100
    baz.should_receive(:amount).and_return 200
    presenter = SingleObjectWithConstructorRequirementsPresenter.new(:foo => foo, :bar => bar, :baz => baz)
    presenter.sum.should == 300
  end
  
  it "raises when the object being presented on isn't passed in" do
    lambda { 
      SingleObjectPresenter.new(:ignored_argument => "here")
    }.should raise_error(ArgumentError, "missing arguments: foo")
  end
  
  it "raises when required constructor arguments aren't passed in" do
    lambda { 
      SingleObjectWithConstructorRequirementsPresenter.new(:foo => mock("foo"))
    }.should raise_error(ArgumentError, "missing arguments: bar, baz")
  end

  it "caches method calls without arguments" do
    foo = mock("foo")
    foo.should_receive(:speak).with().at_most(1).times.and_return "Speaking!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.talk.should == "Speaking!"
    presenter.talk.should == "Speaking!"
  end
  
  it "caches method calls with arguments" do
    foo = mock("foo")
    foo.should_receive(:run).with(:far).at_most(1).times.and_return "Running far!"
    foo.should_receive(:run).with(:near).at_most(1).times.and_return "Running nearby!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.run(:far).should == "Running far!"
    presenter.run(:far).should == "Running far!"
    presenter.run(:near).should == "Running nearby!"
    presenter.run(:near).should == "Running nearby!"
  end
  
  it "returns results from different method calls with the same arguments" do
    foo = mock("foo")
    foo.should_receive(:walk).with(:far).at_most(1).times.and_return "Walking far!"
    foo.should_receive(:run).with(:far).at_most(1).times.and_return "Running far!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.walk(:far).should == "Walking far!"
    presenter.walk(:far).should == "Walking far!"
    presenter.run(:far).should == "Running far!"
    presenter.run(:far).should == "Running far!"
  end
  
  it "doesn't cache method calls with blocks" do
    foo = mock("foo")
    foo.should_receive(:speak).with().exactly(2).times().and_return "Speaking!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.talk { |o| o.speak }.should == "Speaking!"
    presenter.talk { |o| o.speak }.should == "Speaking!"
  end
  
  it "doesn't break method calls with blocks" do
    arr = [1,2,3]
    presenter = ArrayPresenter.new :arr => arr
    presenter.map{ |i| i**2 }.should == [1,4,9]
    presenter.map{ |i| i**3 }.should == [1,8,27]
  end
    
  it "caches explicitly delegated methods" do
    foo = mock("foo")
    foo.should_receive(:raise_your_hand).with().at_most(1).times.and_return "raising my hand"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.raise_your_hand.should == "raising my hand"
    presenter.raise_your_hand.should == "raising my hand"    
  end

  it "doesn't cache explicitly delegated methods with blocks" do
    foo = mock("foo")
    foo.should_receive(:raise_your_hand).with().exactly(2).times.and_return "raising my hand"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.raise_your_hand { }.should == "raising my hand"
    presenter.raise_your_hand { }.should == "raising my hand"
  end

  it "caches explicitly delegated methods with arguments" do
    foo = mock("foo")
    foo.should_receive(:raise_your_hand).with(1, 2, 3).at_most(1).times.and_return "raising my hand"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.raise_your_hand(1, 2, 3).should == "raising my hand"
    presenter.raise_your_hand(1, 2, 3).should == "raising my hand"    
  end
  
  it "caches implicitly delegated methods" do
    foo = mock("foo")
    foo.should_receive(:turkey).at_most(1).times
    presenter = SingleObjectPresenter.new :foo => foo
    presenter.turkey
    presenter.turkey
  end

  it "doesn't cache implicitly delegated methods with blocks" do
    foo = mock("foo")
    foo.should_receive(:turkey).exactly(2).times
    presenter = SingleObjectPresenter.new :foo => foo
    presenter.turkey { }
    presenter.turkey { }
  end
  
  it "works with methods suffixed with a question mark" do
    foo = mock("foo")
    foo.should_receive(:last_day).with().at_most(1).times.and_return true
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.last_day?.should == true
    presenter.last_day?.should == true  
  end

  it "works with methods suffixed with an exclamation point" do
    foo = mock("foo")
    foo.should_receive(:stop).with().at_most(1).times.and_return "stopped"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.stop!.should == "stopped"
    presenter.stop!.should == "stopped"  
  end
  
  it "raises method missing errors when the object being presented on doesn't respond to an unknown method" do
    foo = Object.new
    presenter = SingleObjectPresenter.new(:foo => foo)
    lambda { presenter.amount }.should raise_error(NoMethodError)
  end
  
  it "can present on two methods with the same name on different presenters" do
    bar1 = mock("bar1")
    bar2 = mock("bar2")
    bar1_presenter = FirstBarPresenter.new(:bar => bar1)
    bar2_presenter = SecondBarPresenter.new(:bar => bar2)
    bar1.should_receive(:say).with("apples").and_return "oranges"
    bar2.should_receive(:say).with("bananas").and_return "mango"
    bar1_presenter.say("apples").should == "oranges"
    bar2_presenter.say("bananas").should == "mango"
  end
end
