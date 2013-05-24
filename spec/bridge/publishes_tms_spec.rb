require 'bridge'
require 'iron_cacher'
describe PublishesTms do
  include IronCacher
  
  class MockController
    extend PublishesTms::Base
    publishes_tms :some_client
    attr_accessor :json
  end

  describe "class_attributes" do
    before(:each) do
      @controller ||= MockController.new
    end
    it "should define and set 'as' " do
      @controller.as.should == 'some_client'
    end

    it "should define and set 'published_resource' " do
      @controller.published_resource.should == 'mock'
    end

    it "should define and set 'queue_name' " do
      @controller.queue_name.should == 'some_client_mock'      
    end
  end

  describe "validate_bridge_request?" do
    def do_prep
      controller.class_eval do
        attr_accessor :json
      end
      @cache_key = 'cache_key'
      @tms_id = Time.now.to_i
      @digest = Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@tms_id}--some_client_mock--#{IronCacher::CACHE_NAME}--")
      yield if block_given?
      add_to_cache(@cache_key, @digest)
    end
    
    def controller
      @controller ||= MockController.new
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
end
