class CachingPresenter
  module Rails
    module Helpers
      # ActionController::UrlWriter hooks into the included class.
      # We need to ensure that it is included in the target
      # class, which is either a spec ExampleGroup or the
      # CachingPresenter itself
      def self.included(klass)
        klass.instance_eval do
          # these are order-dependent
          include ActionView::Helpers
          include ActionController::UrlWriter
        end
      end
    end
    
    DO_NOT_PROXY = [/^default_url_options$/]
    
    class ClassProxy
      def initialize(presenter_class, proxy_class)
        @presenter_class = presenter_class
        @proxy_class = proxy_class
      end
    
      def method_missing(method_name, *args, &block)
        if DO_NOT_PROXY.select{ |rgx| method_name.to_s =~ rgx}.any?
          @presenter_class.send(method_name, *args, &block)
        else
          @proxy_class.send(method_name, *args, &block)
        end
      end
    end
  end

  def class
    Rails::ClassProxy.new presenter_class, presents.class
  end
  
  include Rails::Helpers
end