class CachingPresenter
  require 'caching_presenter/memoizable'
  require 'caching_presenter/instantiation_methods'

  include InstantiationMethods

  alias :presenter_class :class
  %w(class id to_param).each do |method|
    undef_method method if respond_to?(method)
  end
  
  def ==(other)
    if other.is_a?(CachingPresenter) && self.presenter_class == other.presenter_class
      instance_variables.sort.map{ |ivar| instance_variable_get(ivar) } == other.instance_variables.sort.map{ |ivar| other.instance_variable_get(ivar) }
    else
      false
    end
  end
  
  def respond_to?(*args)
    super || presents.respond_to?(*args)
  end
  
  def self.inherited(subclass)
    write_presents_for_subclass subclass
    subclass.extend Memoizable
  end
    
  class << self
    def presents(*args)
      if args.size > 0
        @presents = args.first
        options = args.last.is_a?(Hash) ? args.pop : {}
        @cached_instance_methods = Hash.new{ |h,k| h[k] = {}}
        write_constructor :presents => @presents, :options => options
      else
        @presents
      end
    end
    
    private
    
    def write_presents_for_subclass(subclass)
      subclass.instance_variable_set :@presents, presents
    end

    def write_constructor(options)
      constructor_options = options[:options].dup
      if constructor_options.has_key?(:requiring)
        warn "The :requiring option is deprecated. Please use :accepts instead."
      end
      
      valid_options = [:accepts]
      unknown_options = (constructor_options.keys - valid_options).map{ |opt| opt.to_s }
      if unknown_options.any?
        raise ArgumentError, "unknown option(s): #{unknown_options.sort.join(', ')}"
      end

      constructor_options[:accepts] ||= []
      klass = self
      define_method(:initialize) do |args|
        @presents_id = options[:presents]
        args = args.dup
        raise ArgumentError, "missing object to present on: #{@presents_id}" unless args[@presents_id]        
        arguments_to_instantiate = constructor_options[:accepts] + [@presents_id]
        arguments_to_instantiate.each do |key|
          self.instance_variable_set "@#{key}", args[key]
        end
      end

      define_method(:presents) do
        self.instance_variable_get "@#{@presents_id}"
      end

      class_eval <<-EOS, __FILE__, __LINE__
        def method_missing(name, *args, &blk)
          source = instance_variable_get("@#{presents}")
          if source.respond_to?(name)
            presenter_class.class_eval <<-END_INNER_CODE
              def \#{name}(*myargs, &myblk)
                instance_variable_get("@#{presents}").\#{name}(*myargs, &myblk)
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
      memoize method_name
    end
  end
end
