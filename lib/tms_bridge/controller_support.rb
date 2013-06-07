require 'iron_cacher'
module TmsBridge
  module ControllerSupport
    
    module Redact
      def redacts_tms(as, _bridged_resource_names)
        extend TmsBridge::ControllerSupport::Security unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Security)
        self.secure_tms_bridge(as)
        extend TmsBridge::ControllerSupport::Redact::ClassMethods unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Redact::ClassMethods)
        include TmsBridge::ControllerSupport::Redact::InstanceMethods unless included_modules.include?(TmsBridge::ControllerSupport::Redact::InstanceMethods)
        
        self.bridged_resource_names=_bridged_resource_names
        
class_eval <<-RUBY, __FILE__, __LINE__+1
        def create
          @record_class = self.bridged_resource_class
          if @record_class
            if @record = @record_class.find_by_tms_id(@json['tms_id'])
              @record.destroy
            end
            render text: 'success'
          else
            head :ok
          end
        end
RUBY
      end

      module ClassMethods
        def self.extended(base)
          base.class_attribute(:bridged_resource_names)
        end
      end      
      
      
      module InstanceMethods
        def bridged_resource_class
          class_name = @json['record_class']
          eval(class_name) if self.class.bridged_resource_names.include?(class_name)
        end
      end
    end

    module Publish
      def publishes_tms(as)
        extend TmsBridge::ControllerSupport::Security unless (class << self; included_modules; end).include?(TmsBridge::ControllerSupport::Security)
        self.secure_tms_bridge(as)
        class_name = self.bridged_resources.classify
  
      class_eval <<-RUBY, __FILE__, __LINE__+1
        def create
          @#{self.bridged_resource} = #{class_name}.find_by_tms_id(@json['tms_id']) || #{class_name}.new
          if @#{self.bridged_resource}
            @#{self.bridged_resource}.attributes = @json['#{self.bridged_resource}'].slice(*#{class_name}.published_attribute_names)
            @#{self.bridged_resource}.save(validate: false)
          end
          render text: 'success'
        end        
      RUBY
  
 
      end
      
  
    end
    
    module Security
      
      def secure_tms_bridge(as)
        include TmsBridge::ControllerSupport::Security::InstanceMethods
        extend TmsBridge::ControllerSupport::Security::ClassMethods
        self.as = as.to_s
        self.bridged_resources = self.name.split('::').last.gsub(/Controller/, '').underscore
        self.bridged_resource = self.bridged_resources.singularize
        self.queue_name = self.as + '_'+self.bridged_resources        
      end

      module InstanceMethods
        include IronCacher
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
      
  
      module ClassMethods
        def self.extended(base)
          base.class_attribute(:queue_name)
          base.class_attribute(:as)
          base.class_attribute(:bridged_resource)
          base.class_attribute(:bridged_resources)
        
          base.before_filter :parse_iron_mq_json
        end
        
      end
      
    end

  end
  
  
end

ActionController::Base.send(:extend, TmsBridge::ControllerSupport::Publish)
ActionController::Base.send(:extend, TmsBridge::ControllerSupport::Redact)