module TmsBridge
  module ModelSupport
    def published_attribute_names
      _attributes_names = self.column_names - %w{id created_at updated_at}
      _attributes_names+=self.attribute_aliases.keys
      return _attributes_names.compact.map(&:to_s).uniq
    end
  end
end
ActiveRecord::Base.send(:extend, TmsBridge::ModelSupport)
