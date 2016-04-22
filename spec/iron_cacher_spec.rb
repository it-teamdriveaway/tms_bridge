require 'rspec'
require File.expand_path(File.dirname(__FILE__) + '/../lib/iron_cacher')

describe IronCacher do
  class MockIronCache
    extend IronCacher
  end

  describe "iron_cache_client" do
    it "return an iron cache client  instance" do
      expect(MockIronCache.iron_cache_client).to be_a(IronCache::Client)
    end
    
    it "should use a separate config file from the iron.json" do
      expect(MockIronCache.iron_cache_client.project_id).to eq(JSON.parse(File.read("config/iron.json"))['project_id'])
    end

  end
  
  describe "iron_cache" do
    it "return an iron cache instance" do
      expect(MockIronCache.iron_cache).to be_a(IronCache::Cache)
    end
    
    it "should should return the cache with the name of the as CACHE_NAME" do
      expect(MockIronCache.iron_cache.name).to eq(IronCacher::CACHE_NAME)
    end    
  end
  
  describe "add_to_cache" do
    before(:each) do
      @key=Time.now.to_f.to_s
    end

    it "should return the key" do
      expect(MockIronCache.add_to_cache(@key, 'value')).to eq(@key)
    end
  
    it "should add an expiry" do
      MockIronCache.add_to_cache(@key, 'value')
      expires = MockIronCache.iron_cache.get(@key)['expires']
      expect(DateTime.parse(expires)).to be < DateTime.parse('9999-01-01T00:00:00+00:00')
    end

  end  
  
  describe "random_key_and_value" do
    it "should return an array" do
      expect(MockIronCache.random_key_and_value(IronCacher::CACHE_NAME).class).to eq(Array)
    end
    
    it "should return the key as the first element and value in cache as the second" do
      key,value = MockIronCache.random_key_and_value(IronCacher::CACHE_NAME)
      expect(MockIronCache.iron_cache.get(key).value).to eq(value)
    end
  end

end