module CachingPresenter::InstantiationMethods
  def Presenter(obj)
    presenter_class_name = "#{obj.class.name}Presenter"
    if Object.const_defined?(presenter_class_name)
      presenter_class = Object.const_get(presenter_class_name)
      presenter_class.new presenter_class.presents => obj
    else
      raise "#{presenter_class_name} was not found for #{obj.inspect}"
    end
  end
end
