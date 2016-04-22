require 'rspec'
require 'tms_bridge'
require File.expand_path(File.dirname(__FILE__) + '/mocks')

describe TmsBridge::ModelSupport do
  describe "published_attributes" do
    # it "should not include 'id'" do
    #   MockModel.published_attribute_names.should_not include('id')
    # end
    #
    # it "should not include 'created_at'" do
    #   MockModel.published_attribute_names.should_not include('created_at')
    # end
    #
    # it "should not include 'updated_at" do
    #   MockModel.published_attribute_names.should_not include('updated_at')
    # end
    #
    # it "should include items declared in column_names" do
    #   MockModel.published_attribute_names.should include('some_key')
    # end
    
    it "should include alias_attributes" do
      MockModel.should_receive(:attribute_aliases){{"alias_key"=>"some_key"}}
      MockModel.published_attribute_names.should include('alias_key')
    end
  end
end