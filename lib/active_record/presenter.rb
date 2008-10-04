module ActiveRecord
  class Presenter
    delegate :id, :class, :errors, :new_record?, :to_param, :to => :presenting_on

    def self.inherited(subclass)
      subclass.extend CacheMethods
    end
    
    module CacheMethods
      def self.extended(klass)
        cached_methods = []
        metaclass = (class <<klass; self; end)
        metaclass.class_eval do
          define_method(:cache_method) do |method_name|
            method_name = method_name.to_s
            return if method_name =~ /^(initialize|method_missing)$/
            return if cached_methods.include?(method_name)
            cached_methods << method_name
            memoize(method_name)
          end
        end
      end
      
      def memoize(method_name)
        unbound_method = instance_method(method_name)
        define_method method_name do |*args|
          cache = {}
          bound_method = unbound_method.bind(self)
          mc = class <<self ; self; end
          mc.send :define_method, method_name do |*myargs|
            cache.has_key?(myargs) ? cache[myargs] : cache[myargs] = bound_method.call(*myargs)
          end
          send(method_name, *args)
        end
      end
    end
    
    class << self
      def presents_on(model_sym, options={})
        @cached_instance_methods = Hash.new{ |h,k| h[k] = {}}
        write_constructor :presenting_on => model_sym, :options => options
      end
      
      private
    
      def write_constructor(options)
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
      
        define_method(:method_missing) do |name, *args|
          if presenting_on.respond_to?(name)
            presenting_on.send(name, *args)
          else
            super
          end
        end
      end
      
      def method_added(method_name)
        cache_method(method_name)
      end
    end
  end
end