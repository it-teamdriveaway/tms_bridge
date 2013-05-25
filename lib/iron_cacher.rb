require 'iron_cache'
require 'uuidtools'

module IronCacher
  CACHE_NAME='bridge-troll'
  DEFAULT_EXPIRES_IN = 60*5
  def iron_cache_client
    IronCache::Client.new(project_id: ENV['IRON_CACHE_PROJECT_ID'], token: ENV['IRON_CACHE_TOKEN'])
  end

  def iron_cache(cache_name=CACHE_NAME)
    iron_cache_client.cache(cache_name)
  end

  def add_to_cache(token, task_id, cache_name=CACHE_NAME)
    iron_cache(cache_name).put(token, task_id, expires_in: IronCacher::DEFAULT_EXPIRES_IN)
    token
  end

  def retrieve_from_cache(token, cache_name=CACHE_NAME)
    if item=iron_cache(cache_name).get(token)
      return item.value
    end
  end
  
  def random_key_and_value(cache_name)
    key = UUIDTools::UUID.random_create.to_s
    value = UUIDTools::UUID.random_create.to_s
    add_to_cache(key, value, cache_name)
    
    return [key, value]    
  end
end