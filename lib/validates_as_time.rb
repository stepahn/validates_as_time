class ValidatesAsTime
  @@default_configuration = {
    :default => Time.now,
    :format => "%Y-%m-%d %H:%M",
    :message => ActiveRecord::Errors.default_error_messages[:invalid],
    :blank => ActiveRecord::Errors.default_error_messages[:blank],
    :too_early => "cannot be before %s",
    :too_late => "cannot be on or after %s",
    :allow_nil => true
  }
  cattr_accessor :default_configuration
end

module ActiveRecord
  module Validations
    module ClassMethods

      def validates_as_time(*attr_names)
        configuration = ValidatesAsTime.default_configuration.merge(attr_names.extract_options!)
        attr_names.each do |attr_name|
          define_method("#{attr_name}_string") do
            return str if str = instance_variable_get("@_#{attr_name}_string")

            c = send(attr_name) || (Object.const_defined?(:Chronic) ? Chronic.parse(configuration[:default]) : Time.parse(configuration[:default]))
            c.strftime(configuration[:format]) if c
          end

          define_method("#{attr_name}_string=") do |str|
            begin
              instance_variable_set("@_#{attr_name}_string", str)

              if str.blank?
                write_attribute(attr_name, nil)
              else
                if Object.const_defined?(:Chronic)
                  c = Chronic.parse(str)
                  raise ArgumentError if c.nil?
                  write_attribute(attr_name, c)
                else
                  write_attribute(attr_name, Time.parse(str))
                end
              end
            rescue ArgumentError
              instance_variable_set("@_#{attr_name}_invalid", true)
            end
          end

          validates_each attr_name do |record, attr, value|
            if record.instance_variable_defined?("@_#{attr_name}_invalid") && record.instance_variable_get("@_#{attr_name}_invalid")
              record.errors.add(attr, configuration[:message])
              next
            end
            if value.nil?
              record.errors.add(attr, configuration[:blank]) unless configuration[:allow_nil]
              next
            end
            if configuration[:minimum] && (value < configuration[:minimum])
              record.errors.add(attr, configuration[:too_early] % configuration[:minimum].strftime(configuration[:format]))
            end
            if configuration[:maximum] && (value >= configuration[:maximum])
              record.errors.add(attr, configuration[:too_late] % configuration[:maximum].strftime(configuration[:format]))
            end
          end
        end
      end
    end
  end
end

