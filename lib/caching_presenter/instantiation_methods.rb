module CachingPresenter::InstantiationMethods
  def present(obj, options={})
    presenter_class_name = "#{options[:as] || obj.class.name}Presenter"
    presenter_class = Object.const_get presenter_class_name
    presenter_class.new presenter_class.presents => obj
  rescue LoadError
    raise "#{presenter_class_name} was not found for #{obj.inspect}"
  end
  
  def present_collection(collection, options={})
    collection.map!{ |e| present(e, options) }
  end
end
