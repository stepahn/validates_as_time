class ValidatesAsTime
  @@default_options = {
    :default => Time.now,
    :format => "%Y-%m-%d %H:%M",
    :message => ActiveRecord::Errors.default_error_messages[:invalid],
    :blank => ActiveRecord::Errors.default_error_messages[:blank],
    :too_early => "cannot be before %s",
    :too_late => "cannot be on or after %s",
    :allow_nil => true,
    :preparser => nil
  }
  cattr_accessor :default_options
end

module ActiveRecord
  module Validations
    module ClassMethods

      def validates_as_time(*attr_names)
        parser = Object.const_defined?(:Chronic) ? Chronic : Time

        options = ValidatesAsTime.default_options.merge(attr_names.extract_options!)

        attrs = attr_names.collect { |a| [a, "#{a}_string"]}
        attrs.flatten!
        validates_each(attrs, options) do |record, attr_name, value|
          attr_name = attr_name.to_s.sub(/_string$/, "")
          next if record.errors[attr_name]
          value = record.send("#{attr_name}")
          if record.instance_variable_defined?("@_#{attr_name}_invalid") and
             record.instance_variable_get("@_#{attr_name}_invalid")
            record.errors.add(attr_name, options[:message])
          elsif value.nil?
            record.errors.add(attr_name, options[:blank]) unless options[:allow_nil]
          elsif options[:minimum] and value < options[:minimum]
            record.errors.add(attr_name, options[:too_early] % options[:minimum].strftime(options[:format]))
          elsif options[:maximum] and value >= options[:maximum]
            record.errors.add(attr_name, options[:too_late] % options[:maximum].strftime(options[:format]))
          end
        end

        attr_names.each do |attr_name|
          define_method("#{attr_name}") do
            read_attribute("#{attr_name}")
          end

          define_method("#{attr_name}=") do |time|
            write_attribute("#{attr_name}", time)
            write_attribute("#{attr_name}_string", nil)
          end

          define_method("#{attr_name}_string") do
            value = read_attribute("#{attr_name}_string")
            return value if value
            c = send("#{attr_name}")
            if c.nil?
              if options[:default].is_a?(String)
                str = options[:default]
                if options[:preparser]
                  if options[:preparser].is_a?(Symbol)
                    str = self.send(options[:preparser], str)
                  elsif options[:preparser].respond_to?(:call)
                    str = options[:preparser].call(str)
                  end
                end
                c = parser.parse(str)
              else
                c = options[:default]
              end
            end
            c.strftime(options[:format]) if c
          end

          define_method("#{attr_name}_string=") do |str|
            begin
              str = nil if str.blank?
              unless str
                send("#{attr_name}=", nil)
              else
                write_attribute("#{attr_name}_string", str)
                if options[:preparser]
                  if options[:preparser].is_a?(Symbol)
                    str = self.send(options[:preparser], str)
                  elsif options[:preparser].respond_to?(:call)
                    str = options[:preparser].call(str)
                  end
                end
                c = parser.parse(str)
                raise ArgumentError if c.nil?
                send("#{attr_name}=", c)
              end
            rescue ArgumentError
              instance_variable_set("@_#{attr_name}_invalid", true)
            end
          end
        end
      end
    end
  end
end

