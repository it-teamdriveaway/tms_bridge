require 'rspec'
require 'tms_bridge'
describe TmsBridge::ControllerSupport do
  include IronCacher
  
  class MocksController
    extend TmsBridge::ControllerSupport::Base
    publishes_tms :some_client
    attr_accessor :json
    attr_reader :mock
    def render(*args)
    end
  end

  class FoundMock
    def save(*args)
    end
    
    def attributes=(*args)
    end
  end

  class Mock
    attr_accessor :attributes, :called_save
    NOT_FOUND=false
    FOUND=true
    def save(parameters)
      self.called_save = true
    end
    
    def self.find_by_tms_id(tms_id)
      return tms_id == FOUND ? FoundMock.new : nil
    end
  end

  def controller
    @controller ||= MocksController.new
  end

  describe "class_attributes" do
    before(:each) do
      @controller ||= MocksController.new
    end
    it "should define and set 'as' " do
      @controller.as.should == 'some_client'
    end

    it "should define and set 'published_resource' " do
      @controller.published_resource.should == 'mock'
    end

    it "should define and set 'published_resources' " do
      @controller.published_resources.should == 'mocks'
    end

    it "should define and set 'queue_name' " do
      @controller.queue_name.should == 'some_client_mocks'
    end
  end

  describe "methods" do
    it "should define 'create'" do
      MocksController.new.should respond_to(:create)
    end
  end

  describe "validate_bridge_request?" do
    def do_prep
      @cache_key = 'cache_key'
      @tms_id = Time.now.to_i
      @digest = Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@tms_id}--some_client_mocks--#{IronCacher::CACHE_NAME}--")
      yield if block_given?
      add_to_cache(@cache_key, @digest)
    end
    
    it "should do something " do
      do_prep
      controller.json = {'cache_key'=>@cache_key, 'tms_id'=>@tms_id}      
      controller.should be_valid_bridge_request
    end
    
    it "should be false if the hash does not match" do
      do_prep
      controller.json = {'cache_key'=>Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@tms_id}--some_client_mock_deletes--#{IronCacher::CACHE_NAME}--"), 'tms_id'=>@tms_id}      
      controller.should_not be_valid_bridge_request
    end
    
    it "should be false if the cache value is not found" do
      do_prep
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.should_not be_valid_bridge_request
    end

    it "should be false if json is null" do
      do_prep
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.json = nil
      controller.should_not be_valid_bridge_request
    end

    it "should be false if no cache_key was passed" do
      do_prep
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.json = {'tms_id'=>@tms_id}      
      controller.should_not be_valid_bridge_request
    end
    
  end
  
  describe "create" do
    before(:each) do
      @attributes = {some_key: 'some value'}
      @tms_id = Mock::NOT_FOUND
      controller.json = {'mock'=>@attributes, 'tms_id'=>@tms_id}
    end
    
    it "should assign to the mock attribute" do
      controller.create
      controller.mock.should_not be_nil
    end
    
    it "should assign to attributes" do
      controller.create
      controller.mock.attributes.should == @attributes
    end
    
    it "it should call Mock.find_by_tms_id" do
      Mock.should_receive(:find_by_tms_id).with(@tms_id)
      controller.create
    end

    it "it should call Mock.new if Mock.find_by_tms_id returns nil" do
      Mock.should_receive(:new)
      controller.create
    end
    
    it "it should call Mock.new if Mock.find_by_tms_id returns nothing" do
      controller.json = {'mock'=>@attributes, 'tms_id'=>Mock::NOT_FOUND}      
      Mock.should_receive(:new)
      controller.create
    end
    
    it "should call save on the mock model" do
      controller.create
      controller.mock.called_save.should == true
    end
    it "should call render " do
      controller.should_receive(:render).with(text: 'success')
      controller.create
    end
  end
end
