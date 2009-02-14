class CachingPresenter
  module Memoizable
    METHOD_PREFIX = "_unmemoized_"
    DO_NOT_MEMOIZE = [/^#{METHOD_PREFIX}/, /^presents$/, /^initialize$/, /^method_missing$/, /^class$/, /=$/]
    REPLACEMENT_ENCODINGS = {
      /\[\]/ => "_square_brackets",
      /\?\Z/ => "_query",
      /\!\Z/ => "_bang"
    }
    
    def self.encode(str)
      str = str.dup
      REPLACEMENT_ENCODINGS.each_pair do |pattern, replacement|
        str.gsub!(pattern, replacement)
      end
      str
    end
    
    def self.encode_ivar(ivar_name)
      "@_memoized_#{encode(ivar_name)}".to_sym
    end
    
    def self.encode_method_name(method_name)
      method_name = "#{METHOD_PREFIX}#{encode(method_name)}"
      method_name.to_sym
    end

    def self.extended(klass)
      cached_methods = []
      klass.instance_variable_set :@cached_methods, []
    end

    def memoize(method_name)
      return if @cached_methods.include?(method_name) || DO_NOT_MEMOIZE.select{ |rgx| method_name.to_s =~ rgx}.any?
      original_method = Memoizable.encode_method_name(method_name)
      @cached_methods << method_name << original_method
      alias_method original_method, method_name

      memoized_ivar = Memoizable.encode_ivar(method_name)
      class_eval <<-EOS, __FILE__, __LINE__
        def #{method_name}(*args, &blk)
          #{memoized_ivar} ||= {}
          if block_given?
            #{original_method}(*args, &blk)
          elsif #{memoized_ivar}.has_key?(args)
            #{memoized_ivar}[args]
          else
            #{memoized_ivar}[args] = #{original_method}(*args)
          end
        end
      EOS
    end
  end
end