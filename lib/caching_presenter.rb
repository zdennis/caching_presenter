require 'caching_presenter/memoizable'
require 'caching_presenter/instantiation_methods'

class CachingPresenter
  include InstantiationMethods
  
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
      constructor_options = options[:options]
      constructor_options[:requiring] ||= []
      klass = self
      
      define_method(:initialize) do |args|
        args = args.dup
        required_arguments = constructor_options[:requiring] + [options[:presents]]
        missing_arguments = required_arguments - args.keys
        raise ArgumentError, "missing arguments: #{missing_arguments.join(', ')}" if missing_arguments.any?
        required_arguments.each do |key|
          self.instance_variable_set "@#{key}", args[key]
        end
      end

      define_method(:presents) do
        self.instance_variable_get "@#{options[:presents]}"
      end

      class_eval <<-EOS, __FILE__, __LINE__
        def method_missing(name, *args, &blk)
          if presents.respond_to?(name)
            self.class.class_eval <<-END_INNER_CODE
              def \#{name}(*myargs, &myblk)
                presents.\#{name}(*myargs, &myblk)
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
