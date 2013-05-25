require 'iron_cacher'
module TmsBridge
  module ControllerSupport
    module Redact
      
    end
    module Publish
      def publishes_tms(as)
        extend TmsBridge::ControllerSupport::Publish::ClassMethods unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Publish::ClassMethods)
        include TmsBridge::ControllerSupport::Publish::InstanceMethods unless included_modules.include?(TmsBridge::ControllerSupport::Publish::InstanceMethods)

        self.as = as.to_s
        self.published_resources = self.name.split('::').last.gsub(/Controller/, '').underscore
        self.published_resource = self.published_resources.singularize

        include TmsBridge::ControllerSupport::Security unless included_modules.include?(TmsBridge::ControllerSupport::Security)
        self.queue_name = self.as + '_'+self.published_resources
 
        class_name = self.published_resources.classify
  
      class_eval <<-RUBY, __FILE__, __LINE__+1
        def create
          @#{self.published_resource} = #{class_name}.find_by_tms_id(@json['tms_id']) || #{class_name}.new
          if @#{self.published_resource}
            @#{self.published_resource}.attributes = @json['#{self.published_resource}']
            @#{self.published_resource}.save(validate: false)
          end
          render text: 'success'
        end        
      RUBY
  
 
      end
      
      module InstanceMethods
        def self.included(base)
          base.send(:include, TmsBridge::ControllerSupport::Security)
        end
      end
  
      module ClassMethods
        def self.extended(base)
          base.class_attribute(:as)
          base.class_attribute(:published_resource)
          base.class_attribute(:published_resources)
        end
      end      
    end

    module Security
      include IronCacher
      
      def self.included(base)
        base.class_attribute(:queue_name)
        base.before_filter :parse_iron_mq_json
      end
  
      protected
      def parse_iron_mq_json
        @json=JSON.parse(request.raw_post) unless request.raw_post.blank?
        unless @json && @json['tms_id']
          head :ok
          return false
        end
      end

      def valid_bridge_request?
        if @json && @json['cache_key']
          value = Digest::SHA2.hexdigest("---#{ENV['CC_BRIDGE_SALT']}--#{@json['tms_id']}--#{self.class.queue_name}--#{IronCacher::CACHE_NAME}--")
          return value == retrieve_from_cache(@json['cache_key'], IronCacher::CACHE_NAME)
        end
      end      
    end


  end
  
  
end

ActionController::Base.send(:extend, TmsBridge::ControllerSupport::Publish)
