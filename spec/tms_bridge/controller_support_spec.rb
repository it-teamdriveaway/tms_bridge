require 'rspec'
require 'tms_bridge'
require File.expand_path(File.dirname(__FILE__) + '/mocks')

describe TmsBridge::ControllerSupport::Security do
  include IronCacher

  class SecuritiesController<MockController
    extend TmsBridge::ControllerSupport::Security
    secure_tms_bridge :some_client
  end

  describe "class attributes" do
    it "should define and set 'as' " do
      expect(SecuritiesController.as).to eq 'some_client'
    end

    it "should define and set 'bridged_resource' " do
      expect(SecuritiesController.bridged_resource).to eq 'security'
    end

    it "should define and set 'bridged_resources' " do
      expect(SecuritiesController.bridged_resources).to eq 'securities'
    end

    it "should define and set 'queue_name' " do
      expect(SecuritiesController.queue_name).to eq 'some_client_securities'
    end

    it "should add :parse_iron_mq_json to the before_filters" do
      expect(SecuritiesController.before_filters).to include(:parse_iron_mq_json)
    end
  end

  describe "validate_bridge_request?" do
    before(:each) do
      @cache_key = 'cache_key'
      @tms_id = Time.now.to_i
      @digest = Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@tms_id}--some_client_securities--#{IronCacher::CACHE_NAME}--")
      yield if block_given?
      add_to_cache(@cache_key, @digest)
    end
    let(:controller) { SecuritiesController.new }

    it "should do something " do
      controller.json = {'cache_key'=>@cache_key, 'tms_id'=>@tms_id}.with_indifferent_access
      expect(controller.send(:valid_bridge_request?)).to eq(true)
    end

    it "should be false if the hash does not match" do
      controller.json = {'cache_key'=>Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@tms_id}--does_not_match--#{IronCacher::CACHE_NAME}--"), 'tms_id'=>@tms_id}.with_indifferent_access
      expect(controller.send(:valid_bridge_request?)).to_not eq(true)
    end

    it "should be false if the cache value is not found" do
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      expect(controller.send(:valid_bridge_request?)).to_not eq(true)
    end

    it "should be false if json is null" do
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.json = nil
      expect(controller.send(:valid_bridge_request?)).to_not eq(true)
    end

    it "should be false if no cache_key was passed" do
      iron_cache(IronCacher::CACHE_NAME).delete(@cache_key)
      controller.json = {'tms_id'=>@tms_id}.with_indifferent_access
      expect(controller.send(:valid_bridge_request?)).to_not eq(true)
    end

  end

  describe "parse_iron_mq_json" do
    def controller
      @controller ||= SecuritiesController.new
    end

    it "should set the json attribute and return nil" do
      controller.request.raw_post=({tms_id: 17}.to_json)
      expect(controller.send(:parse_iron_mq_json)).to be_nil
      expect(controller.json.class).to eq(ActiveSupport::HashWithIndifferentAccess)
    end

    it "should return false and call head with :ok, if tms_id is not present" do
      controller.request.raw_post= nil
      expect(controller).to receive(:head).with(:ok)
      expect(controller.send(:parse_iron_mq_json)).to eq false
    end

  end
end


describe TmsBridge::ControllerSupport::Redact do
  include IronCacher

  class MockRedactionsController<MockController
    attr_reader :record, :record_class
    extend TmsBridge::ControllerSupport::Redact
    redacts_tms :some_client, %w{MockModel}
  end

  def controller
    @controller ||=MockRedactionsController.new
  end

  describe "modules" do
    it "should extend security" do
      expect((class << MockRedactionsController; included_modules; end)).to include(TmsBridge::ControllerSupport::Security)
    end
  end

  describe "class_methods" do
    it "should assign bridged_resources" do
      expect(MockRedactionsController.bridged_resource_names).to eq %w{MockModel}
    end
  end

  describe "instance_methods" do
    describe "bridged_resource_class" do

      it "should eval the string and return it if the json attribute record_class is in MockRedactionsController.bridged_resource_names" do
        controller.json = {'record_class' => 'MockModel'}.with_indifferent_access
        expect(controller.send(:bridged_resource_class)).to eq MockModel
      end

      it "should return nil if the json attribute a record_class is not in MockRedactionsController.bridged_resource_names" do
        controller.json = {'record_class' => 'raise'}.with_indifferent_access
        expect(controller.send(:bridged_resource_class)).to be_nil
      end
    end
  end

  describe "create" do
    describe "bridged_resource_class return a class" do
      before(:each) do
        controller.json={'record_class'=>'MockModel', 'tms_id'=>MockModel::FOUND}.with_indifferent_access
        allow(controller).to receive(:bridged_resource_class){MockModel}
      end

      it "should call controller#bridged_resource_class" do
        expect(controller).to receive(:bridged_resource_class)
        controller.create
      end

      it "should assign to record class" do
        controller.create
        expect(controller.record_class).to eq MockModel
      end

      it "should call MockModel.find_by_tms_id" do
        expect(MockModel).to receive(:find_by_tms_id).with(MockModel::FOUND)
        controller.create
      end

      it "should assign to record if found" do
        controller.create
        expect(controller.record).to be_a(FoundMockPublishing)
      end

      it "should call destroy on the found record" do
        controller.create
        expect(controller.record.called_destroy).to eq true
      end

      it "should call render" do
        expect(controller).to receive(:render).with(plain: 'success')
        controller.create
      end

      it "should not throw an error if the record is not found" do
        controller.json={'record_class'=>'MockModel', 'tms_id'=>MockModel::NOT_FOUND}.with_indifferent_access
        expect(controller.record).to be_nil
        expect(controller).to receive(:render).with(plain: 'success')
        controller.create
      end
    end
  end
  describe "if an invalid record class is passed" do

    before(:each) do
      allow(controller).to receive(:bridged_resource_class)
    end
    it "should call head :ok and" do
      expect(controller).to receive(:head).with(:ok)
      controller.create
      expect(controller.record).to be_nil
    end
  end
end

describe TmsBridge::ControllerSupport::Publish do

  class MockPublishingsController<MockController
    attr_reader :mock_publishing

    extend TmsBridge::ControllerSupport::Publish
    publishes_tms :some_client
  end

  def controller
    @controller ||= MockPublishingsController.new
  end

  describe "modules" do
    it "should extend security" do
      expect((class << MockPublishingsController; included_modules; end)).to include(TmsBridge::ControllerSupport::Security)
    end

    it "should support update_only?" do
      expect(controller.update_only?).to eq controller.class.update_only
    end

  end

  def widget_controller(params={})
    Class.new do
      extend TmsBridge::ControllerSupport::Publish
      class << self
        def before_action(*args)
        end
        alias_method :before_filter, :before_action
        def name
          "WidgetsController"
        end
      end
      publishes_tms :some_client, params
    end

  end

  describe "class_methods" do

    it "should set update_only to false by default" do
      expect(widget_controller.update_only).to eq false
    end

    it "should support manually setting update_only" do
      expect(widget_controller(:update_only=>true).update_only).to eq true
    end

    it "should support setting model_params_key" do
      expect(widget_controller(:model_params_key=>'something_else').model_params_key).to eq 'something_else'
    end

    it "should set model_params_key to bridged_resource by default" do
      expect(widget_controller.model_params_key).to eq widget_controller.bridged_resource
    end

    it "should support setting bridged_resource_names" do
      expect(widget_controller(:bridged_resource_names=>['SomethingElse']).bridged_resource_names).to eq ['SomethingElse']
    end

    it "should set bridged_resource_names to bridged_resource by default" do
      expect(widget_controller.bridged_resource_names).to eq ['Widget']
    end

    it "should support setting bridged_resource_name" do
      expect(widget_controller(:bridged_resource_names=>['SomethingElse']).bridged_resource_name).to eq 'SomethingElse'
    end

    it "should set bridged_resource_names to bridged_resource by default" do
      expect(widget_controller.bridged_resource_name).to eq 'Widget'
    end

  end

  describe "instance_methods" do

    it "should return the value of class's update_only for update_only?" do
      controller = widget_controller
      expect(controller).to receive(:update_only){true}
      controller.new.update_only?
    end

    it "should return the value of the class's model_params_key" do
      controller = widget_controller
      expect(controller).to receive(:model_params_key)
      controller.new.model_params_key

    end
  end

  describe "create" do
    before(:each) do
      @attributes = {'some_key'=>'some value'}
      @tms_id = MockPublishing::NOT_FOUND
      @bridge_id = 'somebridgeid'
      controller.json = {'mock_publishing'=>@attributes, 'tms_id'=>@tms_id, 'bridge_id'=>@bridge_id}.with_indifferent_access
    end

    it "should assign to the mock_publishing attribute" do

      controller.create
      expect(controller.mock_publishing).to_not be_nil
    end

    it "should assign to attributes" do
      controller.create
      expect(controller.mock_publishing.attributes).to eq(ActionController::Parameters.new(@attributes).permit('some_key'))
    end

    it "it should call MockPublishing.find_by_tms_id" do
      expect(MockPublishing).to receive(:find_by_tms_id).with(@tms_id)
      controller.create
    end

    it "it should call MockPublishing.new if MockPublishing.find_by_tms_id returns nil" do
      expect(MockPublishing).to receive(:new)
      controller.create
    end

    it "should not pass attributes to the mock model taht are not supported" do
      expect(MockPublishing).to receive(:published_attribute_names){['some_key']}
      controller.create
    end

    it "it should call MockPublishing.new if MockPublishing.find_by_tms_id returns nothing" do
      controller.json = {'mock_publishing'=>@attributes, 'tms_id'=>MockPublishing::NOT_FOUND}.with_indifferent_access
      expect(MockPublishing).to receive(:new)
      controller.create
    end

    it "it should call MockPublishing.new if MockPublishing.find_by_tms_id returns nothing and update_only? == true" do
      controller.json = {'mock_publishing'=>@attributes, 'tms_id'=>MockPublishing::NOT_FOUND}.with_indifferent_access
      expect(MockPublishing).to_not receive(:new)
      allow(controller).to receive(:update_only?){true}
      controller.create
    end

    it "should call save on the mock_publishing model" do
      controller.create
      expect(controller.mock_publishing.called_save).to eq true
    end

    it "should call render " do
      expect(controller).to receive(:render).with(plain: 'success')
      controller.create
    end

    it "should attempt a lookup of the model with bridge_id if not found by tms_id an supports bridge_id" do
      expect(MockPublishing).to receive(:find_by_tms_id).with(@tms_id){nil}
      column_names = MockPublishing.column_names + ['bridge_id']
      allow(MockPublishing).to receive(:column_names){column_names}
      expect(MockPublishing).to receive(:find_by_bridge_id).with(@bridge_id)
      controller.create
    end

    it "should attempt a lookup of the model with bridge_id if not found by tms_id an supports bridge_id, but bridge_id is blank" do
      expect(MockPublishing).to receive(:find_by_tms_id).with(@tms_id){nil}
      column_names = MockPublishing.column_names + ['bridge_id']
      allow(MockPublishing).to receive(:column_names){column_names}
      expect(MockPublishing).to_not receive(:find_by_bridge_id).with(@bridge_id)
      controller.json['bridge_id'] = nil
      controller.create
    end

    it "should set the attributes according to model_params_key" do
      @attributes = {'some_key'=>'value'}

      controller.json={'record_class'=>'MockPublishing', 'tms_id'=>MockModel::FOUND, 'mock_publishing'=>@attributes}
      controller.create
      expect(controller.mock_publishing).to be_a(FoundMockPublishing)
      expect(controller.mock_publishing.attributes).to eq ActionController::Parameters.new(@attributes).permit("some_key")
    end


  end
end
