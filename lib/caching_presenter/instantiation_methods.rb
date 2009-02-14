class CachingPresenter
  module InstantiationMethods
    def present(obj, options={})
      options = options.dup
      presenter_class_name = "#{options.delete(:as) || obj.class.name}Presenter"
      presenter_class = _constantize(presenter_class_name)
      presenter_class.new options.merge(presenter_class.presents => obj)
    rescue LoadError
      raise "#{presenter_class_name} was not found for #{obj.inspect}"
    end
  
    def present_collection(collection, options={})
      collection.map!{ |e| present(e, options) }
    end
  
    private

    # Thanks Rails!
    #
    # Ruby 1.9 introduces an inherit argument for Module#const_get and
    # #const_defined? and changes their default behavior.
    if Module.method(:const_get).arity == 1
      # Tries to find a constant with the name specified in the argument string:
      #
      #   "Module".constantize     # => Module
      #   "Test::Unit".constantize # => Test::Unit
      #
      # The name is assumed to be the one of a top-level constant, no matter whether
      # it starts with "::" or not. No lexical context is taken into account:
      #
      #   C = 'outside'
      #   module M
      #     C = 'inside'
      #     C               # => 'inside'
      #     "C".constantize # => 'outside', same as ::C
      #   end
      #
      # NameError is raised when the name is not in CamelCase or the constant is
      # unknown.
      def _constantize(camel_cased_word)
        names = camel_cased_word.split('::')
        names.shift if names.empty? || names.first.empty?

        constant = Object
        names.each do |name|
          constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
        end
        constant
      end
    else
      def _constantize(camel_cased_word) #:nodoc:
        names = camel_cased_word.split('::')
        names.shift if names.empty? || names.first.empty?

        constant = Object
        names.each do |name|
          constant = constant.const_get(name, false) || constant.const_missing(name)
        end
        constant
      end
    end
  end
end
