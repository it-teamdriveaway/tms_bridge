require 'rspec'
require 'tms_bridge'

describe TmsBridge::ControllerSupport::Security do
  include IronCacher
  
  class MockRequest
    attr_accessor :raw_post
  end

  class SecurityController
    attr_accessor :json
    attr_reader :request
    
    def self.before_filter(*args);end
    include TmsBridge::ControllerSupport::Security
    self.queue_name = 'some_secure_queue_name'
    
    def initialize
      @request = MockRequest.new
    end
    
    def head(*args)
    end
  end
  
  describe "validate_bridge_request?" do
    before(:each) do
      @cache_key = 'cache_key'
      @tms_id = Time.now.to_i
      @digest = Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@tms_id}--some_secure_queue_name--#{IronCacher::CACHE_NAME}--")
      yield if block_given?
      add_to_cache(@cache_key, @digest)
    end
    def controller
      @controller ||= SecurityController.new
    end
    
    it "should do something " do
      controller.json = {'cache_key'=>@cache_key, 'tms_id'=>@tms_id}      
      controller.should be_valid_bridge_request
    end
    
    it "should be false if the hash does not match" do
      controller.json = {'cache_key'=>Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@tms_id}--does_not_match--#{IronCacher::CACHE_NAME}--"), 'tms_id'=>@tms_id}      
      controller.should_not be_valid_bridge_request
    end
    
    it "should be false if the cache value is not found" do
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.should_not be_valid_bridge_request
    end
  
    it "should be false if json is null" do
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.json = nil
      controller.should_not be_valid_bridge_request
    end
  
    it "should be false if no cache_key was passed" do
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.json = {'tms_id'=>@tms_id}      
      controller.should_not be_valid_bridge_request
    end
    
  end
  
  describe "parse_iron_mq_json" do
    def controller
      @controller ||= SecurityController.new
    end

    it "should set the json attribute and return nil" do
      controller.request.raw_post=({:tms_id=>17}.to_json)
      controller.send(:parse_iron_mq_json).should be_nil
      controller.json.class.should eq(Hash)
    end
    
    it "should return false and call head with :ok, if tms_id is not present" do
      controller.request.raw_post= nil
      controller.should_receive(:head).with(:ok)
      controller.send(:parse_iron_mq_json).should == false
    end
    
  end
end

describe TmsBridge::ControllerSupport::Publish do
  include IronCacher
  
  class MocksController
    attr_accessor :json
    attr_reader :mock

    def self.before_filter(*args);end
    def render(*args);end

    extend TmsBridge::ControllerSupport::Publish
    publishes_tms :some_client
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
