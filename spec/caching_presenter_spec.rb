require File.expand_path(File.dirname(__FILE__) + "/spec_helper")

class SingleObject
end

class FooPresenter < CachingPresenter
  presents :foo
end

module Example
  class NamedSpacedObject
  end

  class NamedSpacedObjectPresenter < CachingPresenter
    presents :foo
  end  
end

class SingleObjectPresenter < CachingPresenter
  extend Forwardable
  
  presents :foo

  def_delegator :@foo, :raise_your_hand
  def_delegator :@foo, :to_s

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

class RequiringPresenter < CachingPresenter
  presents :foo, :requiring => [:bar]
end

class FirstBar
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
  
  def list
    @arr.map{ |item| present(item) }
  end
end

class SubclassedPresenter < SingleObjectPresenter
end

describe CachingPresenter do
  it "should know what it is presenting on" do
    SingleObjectPresenter.presents.should == :foo
    SubclassedPresenter.presents.should == :foo
  end

  %w(class id to_param).each do |method|
    it "should always delegate #{method} to the source of the presenter" do
      foo = stub("foo", method => "Result")
      presenter = SingleObjectPresenter.new(:foo => foo)
      eval("presenter.#{method}").should == "Result"
    end
  end
  
  it "should delegate respond_to? to the object being presented when the presenter can't answer it" do
    foo = stub("foo", :something_crazy => "yes")
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.should respond_to(:something_crazy)
  end
  
  it "should automatically delegate methods that exist on the object being presented to that object" do
    foo = mock("foo")
    foo.should_receive(:amount).and_return 10
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.amount.should == 10
  end
  
  it "should be able to present on an object with additional constructor requirements" do
    foo, bar, baz = mock("foo"), mock("bar"), mock("baz")
    bar.should_receive(:amount).and_return 100
    baz.should_receive(:amount).and_return 200
    presenter = SingleObjectWithConstructorRequirementsPresenter.new(:foo => foo, :bar => bar, :baz => baz)
    presenter.sum.should == 300
  end
  
  it "should raise when the object being presented on isn't passed in" do
    lambda { 
      SingleObjectPresenter.new(:ignored_argument => "here")
    }.should raise_error(ArgumentError, "missing arguments: foo")
  end
  
  it "should raise when required constructor arguments aren't passed in" do
    lambda { 
      SingleObjectWithConstructorRequirementsPresenter.new(:foo => mock("foo"))
    }.should raise_error(ArgumentError, "missing arguments: bar, baz")
  end

  it "should cache method calls without arguments" do
    foo = mock("foo")
    foo.should_receive(:speak).with().at_most(1).times.and_return "Speaking!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.talk.should == "Speaking!"
    presenter.talk.should == "Speaking!"
  end
  
  it "should cache method calls with arguments" do
    foo = mock("foo")
    foo.should_receive(:run).with(:far).at_most(1).times.and_return "Running far!"
    foo.should_receive(:run).with(:near).at_most(1).times.and_return "Running nearby!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.run(:far).should == "Running far!"
    presenter.run(:far).should == "Running far!"
    presenter.run(:near).should == "Running nearby!"
    presenter.run(:near).should == "Running nearby!"
  end
  
  it "should return the results from different method calls with the same arguments" do
    foo = mock("foo")
    foo.should_receive(:walk).with(:far).at_most(1).times.and_return "Walking far!"
    foo.should_receive(:run).with(:far).at_most(1).times.and_return "Running far!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.walk(:far).should == "Walking far!"
    presenter.walk(:far).should == "Walking far!"
    presenter.run(:far).should == "Running far!"
    presenter.run(:far).should == "Running far!"
  end
  
  it "should not cache method calls with blocks" do
    foo = mock("foo")
    foo.should_receive(:speak).with().exactly(2).times().and_return "Speaking!"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.talk { |o| o.speak }.should == "Speaking!"
    presenter.talk { |o| o.speak }.should == "Speaking!"
  end
  
  it "should work with method calls that take blocks" do
    arr = [1,2,3]
    presenter = ArrayPresenter.new :arr => arr
    presenter.map{ |i| i**2 }.should == [1,4,9]
    presenter.map{ |i| i**3 }.should == [1,8,27]
  end
    
  it "should cache explicitly delegated methods" do
    foo = mock("foo")
    foo.should_receive(:raise_your_hand).with().at_most(1).times.and_return "raising my hand"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.raise_your_hand.should == "raising my hand"
    presenter.raise_your_hand.should == "raising my hand"    
  end

  it "should not cache explicitly delegated methods with blocks" do
    foo = mock("foo")
    foo.should_receive(:raise_your_hand).with().exactly(2).times.and_return "raising my hand"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.raise_your_hand { }.should == "raising my hand"
    presenter.raise_your_hand { }.should == "raising my hand"
  end

  it "should cache explicitly delegated methods with arguments" do
    foo = mock("foo")
    foo.should_receive(:raise_your_hand).with(1, 2, 3).at_most(1).times.and_return "raising my hand"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.raise_your_hand(1, 2, 3).should == "raising my hand"
    presenter.raise_your_hand(1, 2, 3).should == "raising my hand"    
  end
  
  it "should cache implicitly delegated methods" do
    foo = mock("foo")
    foo.should_receive(:turkey).at_most(1).times
    presenter = SingleObjectPresenter.new :foo => foo
    presenter.turkey
    presenter.turkey
  end

  it "should not cache implicitly delegated methods with blocks" do
    foo = mock("foo")
    foo.should_receive(:turkey).exactly(2).times
    presenter = SingleObjectPresenter.new :foo => foo
    presenter.turkey { }
    presenter.turkey { }
  end
  
  it "should cache methods suffixed with a question mark" do
    foo = mock("foo")
    foo.should_receive(:last_day).with().at_most(1).times.and_return true
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.last_day?.should == true
    presenter.last_day?.should == true  
  end

  it "should cache methods suffixed with an exclamation point" do
    foo = mock("foo")
    foo.should_receive(:stop).with().at_most(1).times.and_return "stopped"
    presenter = SingleObjectPresenter.new(:foo => foo)
    presenter.stop!.should == "stopped"
    presenter.stop!.should == "stopped"  
  end
  
  it "should raise method missing errors when the object being presented on doesn't respond to an unknown method" do
    foo = Object.new
    presenter = SingleObjectPresenter.new(:foo => foo)
    lambda { presenter.amount }.should raise_error(NoMethodError)
  end
  
  it "should be able to present on two methods with the same name, but on different presenters" do
    bar1 = mock("bar1")
    bar2 = mock("bar2")
    bar1_presenter = FirstBarPresenter.new(:bar => bar1)
    bar2_presenter = SecondBarPresenter.new(:bar => bar2)
    bar1.should_receive(:say).with("apples").and_return "oranges"
    bar2.should_receive(:say).with("bananas").and_return "mango"
    bar1_presenter.say("apples").should == "oranges"
    bar2_presenter.say("bananas").should == "mango"
  end
  
  it "should be equivalent to another presenter of the same class when presenting on the same thing" do
    obj = SingleObject.new
    SingleObjectPresenter.new(:foo => obj).should == SingleObjectPresenter.new(:foo => obj)
    SingleObjectPresenter.new(:foo => 4).should == SingleObjectPresenter.new(:foo => 4)
    RequiringPresenter.new(:foo => obj, :bar => 4).should == RequiringPresenter.new(:foo => obj, :bar => 4)
  end
  
  it "should not be equivalent to another presenter of the same class presenting on two different things" do
    SingleObjectPresenter.new(:foo => Object.new).should_not == SingleObjectPresenter.new(:foo => SingleObject.new)
    obj = Object.new
    RequiringPresenter.new(:foo => obj, :bar => 4).should_not == RequiringPresenter.new(:foo => obj, :bar => 5)
    RequiringPresenter.new(:foo => 1, :bar => obj).should_not == RequiringPresenter.new(:foo => 2, :bar => obj)
  end
    
  it "should not be equivalent to a non caching presenter object" do
    obj = SingleObject.new
    SingleObjectPresenter.new(:foo => obj).should_not == 4
  end
  
  it "should not be equivalent to another presenter of a different class when presenting on the same thing" do
    obj, obj2 = SingleObject.new, SingleObject.new
    SingleObjectPresenter.new(:foo => obj).should_not == FooPresenter.new(:foo => obj2)
    SingleObjectPresenter.new(:foo => 4).should_not == FooPresenter.new(:foo => 6)
  end
end


describe CachingPresenter, "creating presenters using present()" do
  include CachingPresenter::InstantiationMethods
  
  it "should be able to create a presenter based on the class of a given instance" do
    obj = SingleObject.new
    present(obj).should == SingleObjectPresenter.new(:foo => obj)
    obj = FirstBar.new
    present(obj).should == FirstBarPresenter.new(:bar => obj)
  end
  
  it "should be able to  create a presenter with a namespaced class" do
    obj = Example::NamedSpacedObject.new
    present(obj).should == Example::NamedSpacedObjectPresenter.new(:foo => obj)
  end
  
  it "should be able to forcefully create a presenter based on an option passed, ignoring the class of a given instance" do
    obj = SingleObject.new
    present(obj, :as => :FirstBar).should == FirstBarPresenter.new(:bar => obj)
    obj = FirstBar.new
    present(obj, :as => :SingleObject).should == SingleObjectPresenter.new(:foo => obj)
  end
  
  it "should raise an error when a presenter can't be found for the given instance" do
    obj = Object.new
    lambda {
      present(obj)
    }.should raise_error(NameError, "uninitialized constant ObjectPresenter")
  end
  
  it "should pass on all options other than :as to the presenter constructor" do
    object = SingleObject.new
    RequiringPresenter.should_receive(:new).with(:foo => object, :bar => 1)
    present object, :as => "Requiring", :bar => 1
  end
end

describe CachingPresenter, "creating a collection of presenters using present_collection()" do
  include CachingPresenter::InstantiationMethods
  
  it "should return an array of presenters based on the class of the elements given" do
    arr = [SingleObject.new, SingleObject.new, FirstBar.new]
    present_collection(arr.dup).should == [
      SingleObjectPresenter.new(:foo => arr[0]), 
      SingleObjectPresenter.new(:foo => arr[1]), 
      FirstBarPresenter.new(:bar => arr[2])]
  end

  it "should return an array of presenters based using a passed in option, ignoring the class of the elements given" do
    arr = [SingleObject.new, SingleObject.new, FirstBar.new]
    present_collection(arr.dup, :as => :FirstBar).should == [
      FirstBarPresenter.new(:bar => arr[0]), 
      FirstBarPresenter.new(:bar => arr[1]), 
      FirstBarPresenter.new(:bar => arr[2])]
  end

  it "should return the same array, not a new one so that Active Record associations can be used" do
    arr = [SingleObject.new]
    def arr.foo
      "foo"
    end
    present_collection(arr).foo.should == "foo"
  end

  it "should raise an error when a presenter can't be found matching the instance" do
    arr = [Object.new]
    lambda {
      present_collection(arr)
    }.should raise_error(NameError, "uninitialized constant ObjectPresenter")
  end
end
