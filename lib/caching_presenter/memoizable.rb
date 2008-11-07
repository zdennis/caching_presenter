class CachingPresenter
  module Memoizable
    MEMOIZED_IVAR = Proc.new do |symbol|
      "@_memoized_#{symbol.to_s.sub(/\?\Z/, '_query').sub(/!\Z/, '_bang')}".to_sym
    end

    def self.extended(klass)
      cached_methods = []
      klass.instance_variable_set :@cached_methods, []
    end

    def memoize(method_name)
      return if @cached_methods.include?(method_name) || method_name.to_s =~ /^(initialize|method_missing|presenting_on)$/
      original_method = :"_unmemoized_#{method_name}"
      @cached_methods << method_name << original_method
      alias_method original_method, method_name

      memoized_ivar = MEMOIZED_IVAR.call(method_name)
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