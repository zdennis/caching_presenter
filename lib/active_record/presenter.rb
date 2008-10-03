module ActiveRecord
  class Presenter
    delegate :id, :class, :errors, :new_record?, :to_param, :to => :presenting_on
    
    def self.presents_on(model_sym, options={})
      write_constructor :presenting_on => model_sym, :options => options
    end
    
    def self.write_constructor(options)
      constructor_options = options[:options]
      constructor_options[:requiring] ||= []
      
      define_method(:initialize) do |args|
        args = args.dup
        required_arguments = constructor_options[:requiring] + [options[:presenting_on]]
        missing_arguments = required_arguments - args.keys
        raise ArgumentError, "missing arguments: #{missing_arguments.join(', ')}" if missing_arguments.any?
        required_arguments.each do |key|
          self.instance_variable_set "@#{key}", args[key]
        end
      end

      define_method(:presenting_on) do
        self.instance_variable_get "@#{options[:presenting_on]}"
      end
    end

    @@cached_instance_methods = Hash.new{ |h,k| h[k] = {}}
    
    def self.method_added(name)
      cache_method(name)
    end

    def self.cache_method(name)
      name = name.to_s
      return if name =~ /((with|without)_caching[\?!]?|initialize)$/
      return if @@cached_instance_methods.include?(name)
      @@cached_instance_methods[name]
      aliased_target, punctuation = name.sub(/([?!])$/, ''), $1
      result = nil
      define_method("#{aliased_target}_with_caching#{punctuation}") do |*args|
        result = send("#{aliased_target}_without_caching#{punctuation}", *args)
        @@cached_instance_methods[name][args] = result
        (class << self ; self ; end).instance_eval do
          define_method(name){ |*myargs| 
            if @@cached_instance_methods[name].has_key?(myargs) 
              @@cached_instance_methods[name][myargs]
            else
              result = send("#{aliased_target}_without_caching#{punctuation}", *myargs)
              @@cached_instance_methods[name][myargs] = result
              result
            end
          }
        end
        result
      end
      alias_method_chain name, :caching
    end
  end
end