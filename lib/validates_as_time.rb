class ValidatesAsTime
  @@default_options = {
    :default => Time.now,
    :format => "%Y-%m-%d %H:%M",
    :message => ActiveRecord::Errors.default_error_messages[:invalid],
    :blank => ActiveRecord::Errors.default_error_messages[:blank],
    :too_early => "cannot be before %s",
    :too_late => "cannot be on or after %s",
    :allow_nil => true
  }
  cattr_accessor :default_options
end

module ActiveRecord
  module Validations
    module ClassMethods

      def validates_as_time(*attr_names)
        parser = Object.const_defined?(:Chronic) ? Chronic : Time

        options = ValidatesAsTime.default_options.merge(attr_names.extract_options!)

        validates_each(attr_names, options) do |record, attr, value|
          if record.instance_variable_defined?("@_#{attr}_invalid") && record.instance_variable_get("@_#{attr}_invalid")
            record.errors.add(attr, options[:message])
          elsif value.nil?
            record.errors.add(attr, options[:blank])
          elsif options[:minimum] && (value < options[:minimum])
            record.errors.add(attr, options[:too_early] % options[:minimum].strftime(options[:format]))
          elsif options[:maximum] && (value >= options[:maximum])
            record.errors.add(attr, options[:too_late] % options[:maximum].strftime(options[:format]))
          end
        end

        attr_names.each do |attr_name|
          define_method("#{attr_name}_string") do
            if str = instance_variable_get("@_#{attr_name}_string")
              return str
            end

            c = read_attribute(attr_name) || parser.parse(options[:default])
            c.strftime(options[:format]) if c
          end

          define_method("#{attr_name}_string=") do |str|
            begin
              instance_variable_set("@_#{attr_name}_string", str)

              c = parser.parse(str)

              if (c.nil? and not options[:allow_nil]) or
                 (c.blank? and not options[:allow_blank])
                raise ArgumentError
              end

              write_attribute(attr_name, c)
            rescue ArgumentError
              instance_variable_set("@_#{attr_name}_invalid", true)
            end
          end
        end
      end
    end
  end
end

