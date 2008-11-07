class CachingPresenter
  def self.inherited(subclass)
    subclass.extend CacheMethods
  end
  
  module CacheMethods
    def self.extended(klass)
      cached_methods = []
      klass.instance_variable_set :@cached_methods, []
    end

    def cache_method(method_name)
      return if @cached_methods.include?(method_name) || method_name.to_s =~ /^(initialize|method_missing|presenting_on)$/
      original_method = :"_unmemoized_#{method_name}"
      @cached_methods << method_name << original_method
      alias_method original_method, method_name
      memoize_without_block method_name, original_method
    end
    
    def memoize_without_block(method_name, original_method_name)
      class_eval <<-EOS, __FILE__, __LINE__
        def #{method_name}(*args, &blk)
          @_memoized_cache ||= {}
          if block_given?
            #{original_method_name}(*args, &blk)
          elsif @_memoized_cache.has_key?(args)
            @_memoized_cache[args]
          else
            @_memoized_cache[args] = #{original_method_name}(*args)
          end
        end
      EOS
    end
  end
  
  class << self
    def presents(model_sym, options={})
      @cached_instance_methods = Hash.new{ |h,k| h[k] = {}}
      write_constructor :presenting_on => model_sym, :options => options
    end
    
    private
  
    def write_constructor(options)
      constructor_options = options[:options]
      constructor_options[:requiring] ||= []
      klass = self
      
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

      class_eval <<-EOS, __FILE__, __LINE__
        def method_missing(name, *args, &blk)
          if presenting_on.respond_to?(name)
            self.class.class_eval <<-END_INNER_CODE
              def \#{name}(*myargs, &myblk)
                presenting_on.\#{name}(*myargs, &myblk)
              end
            END_INNER_CODE
            send(name, *args, &blk)
          else
            super
          end
        end
      EOS
    end
    
    def method_added(method_name)
      cache_method(method_name)
    end
  end
end
