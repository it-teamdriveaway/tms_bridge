require 'rspec'
require 'tms_bridge'
require File.expand_path(File.dirname(__FILE__) + '/mocks')

describe TmsBridge::ModelSupport do
  describe "published_attributes" do
    it "should not include 'id'" do
      expect(MockModel.published_attribute_names).to_not include('id')
    end

    it "should not include 'created_at'" do
      expect(MockModel.published_attribute_names).to_not include('created_at')
    end

    it "should not include 'updated_at" do
      expect(MockModel.published_attribute_names).to_not include('updated_at')
    end

    it "should include items declared in column_names" do
      expect(MockModel.published_attribute_names).to include('some_key')
    end

    it "should include alias_attributes" do
      expect(MockModel).to receive(:attribute_aliases){{"alias_key"=>"some_key"}}
      expect(MockModel.published_attribute_names).to include('alias_key')
    end

    it "should include monetized_attributes" do
      expect(MockModel).to receive(:monetized_attributes){{"monetized_attribute"=>"cents_attribute"}}
      expect(MockModel.published_attribute_names).to include('monetized_attribute')
    end
  end
end