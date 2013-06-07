module TmsBridge
  module ModelSupport
    def published_attribute_names
      self.column_names - %w{id created_at updated_at}
    end
  end
end
ActiveRecord::Base.send(:extend, TmsBridge::ModelSupport)
