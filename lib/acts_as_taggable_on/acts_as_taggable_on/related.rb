module ActsAsTaggableOn::Taggable
  module Related
    def self.included(base)
      base.send :include, ActsAsTaggableOn::Taggable::Related::InstanceMethods
      base.extend ActsAsTaggableOn::Taggable::Related::ClassMethods
      base.initialize_acts_as_taggable_on_related
    end

    module ClassMethods
      def initialize_acts_as_taggable_on_related
        tag_types.map(&:to_s).each do |tag_type|
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def find_related_#{tag_type}(options = {})
              related_tags_for('#{tag_type}', self.class, options)
            end
            alias_method :find_related_on_#{tag_type}, :find_related_#{tag_type}

            def find_related_#{tag_type}_for(klass, options = {})
              related_tags_for('#{tag_type}', klass, options)
            end
          RUBY
        end

        unless tag_types.empty?
          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def find_matching_contexts(search_context, result_context, options = {})
              matching_contexts_for(search_context.to_s, result_context.to_s, self.class, options)
            end

            def find_matching_contexts_for(klass, search_context, result_context, options = {})
              matching_contexts_for(search_context.to_s, result_context.to_s, klass, options)
            end
          RUBY
        end
      end

      def acts_as_taggable_on(*args)
        super(*args)
        initialize_acts_as_taggable_on_related
      end
    end

    module InstanceMethods
      def matching_contexts_for(search_context, result_context, klass, options = {})
        tags_to_find = tags_on(search_context).collect { |t| t.name }
        tag_class = tag_class_for_context(search_context)
        tags_table_name = tag_class.table_name
        taggings_table_name = tagging_class_for_context(search_context).table_name

        klass.select("#{klass.table_name}.*, COUNT(#{tags_table_name}.#{tag_class.primary_key}) AS count") \
             .from("#{klass.table_name}, #{tags_table_name}, #{taggings_table_name}") \
             .where(["#{exclude_self(klass, id)} #{klass.table_name}.#{klass.primary_key} = #{taggings_table_name}.taggable_id AND #{taggings_table_name}.taggable_type = '#{klass.base_class.to_s}' AND #{taggings_table_name}.tag_id = #{tags_table_name}.#{tag_class.primary_key} AND #{tags_table_name}.name IN (?) AND #{taggings_table_name}.context = ?", tags_to_find, result_context]) \
             .group(group_columns(klass)) \
             .order("count DESC")
      end

      def related_tags_for(context, klass, options = {})
				tags_to_ignore = Array.wrap(options.delete(:ignore)).map(&:to_s) || []
        tags_to_find = tags_on(context).collect { |t| t.name }.reject { |t| tags_to_ignore.include? t }
        tag_class = tag_class_for_context(context)
        tags_table_name = tag_class.table_name
        taggings_table_name = tagging_class_for_context(context).table_name

        klass.select("#{klass.table_name}.*, COUNT(#{tags_table_name}.#{tag_class.primary_key}) AS count") \
             .from("#{klass.table_name}, #{tags_table_name}, #{taggings_table_name}") \
             .where(["#{exclude_self(klass, id)} #{klass.table_name}.#{klass.primary_key} = #{taggings_table_name}.taggable_id AND #{taggings_table_name}.taggable_type = '#{klass.base_class.to_s}' AND #{taggings_table_name}.tag_id = #{tags_table_name}.#{tag_class.primary_key} AND #{tags_table_name}.name IN (?)", tags_to_find]) \
             .group(group_columns(klass)) \
             .order("count DESC")
      end

      private
      
      def exclude_self(klass, id)
        if [self.class.base_class, self.class].include? klass
          "#{klass.table_name}.#{klass.primary_key} != #{id} AND" 
        else
          nil
        end
      end

      def group_columns(klass)
        if ActsAsTaggableOn::Tag.using_postgresql? 
          grouped_column_names_for(klass)
        else
          "#{klass.table_name}.#{klass.primary_key}"
        end
      end
    end
  end
end
