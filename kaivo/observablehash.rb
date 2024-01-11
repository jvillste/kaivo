module Kaivo
  class ObservableHash
    include Observable

    attr_accessor :value

    def initialize value = nil, hash = Hash.new
      @value = value
      @hash = hash
    end

    def [] key
      @hash[key]
    end

    def []= key, value
      @hash[key] = value

      changed(true)
      notify_observers( key )
    end

    def load kaivo, loaded_values = Hash.new
      old_keys = Set.new( @hash.keys )
      loaded_values[@value] = self

      transaction = GUI::join_current_transaction( kaivo )

      kaivo.find( @value, nil, nil ).each do | statement |

	object = statement.object
	predicate = statement.predicate
	subject_is_owner = kaivo.subject_is_owner?( statement )

	if( kaivo.call_in_transaction( transaction, :is_of_type?, object, 'Array' ) )

	  array = Array::from_value( kaivo, object )
	  if( subject_is_owner )
	    array.collect! do | item |
	      load_value( kaivo, item, loaded_values )
	    end
	  end

	  ## Do not overwrite observable arrays so that their observers are preserved
	  if( not self[predicate].nil? and self[predicate].kind_of?( ObservableArray ) )
	    self[predicate].clear
	    array.each do | item |
	      self[predicate] << item
	    end
	  else
	    self[ predicate ] = ObservableArray.new( array )
	  end

	else
	  if( subject_is_owner )
	    self[ predicate ] = load_value( kaivo, object, loaded_values )
	  else
	    self[ predicate ] = object
	  end
	end

	old_keys.delete( predicate )
      end

      # remove keys that were not loaded with any new values
      old_keys.each do | key |
	self[key] = nil
      end

      GUI::leave_current_transaction()

    end

    def load_value kaivo, value, loaded_values
      if( loaded_values[value].nil? )
	value = ObservableHash.new( value )
	value.load( kaivo, loaded_values )
      else
	value = loaded_values[value]
      end

      return value
    end

    def save kaivo, as_new = false
      if @value.nil? or as_new
	@value = kaivo.generate_value()
      else
	kaivo.remove_value_and_owned_values( @value )
      end

      @hash.keys.each do | predicate |

	object = @hash[predicate]
	if( object.kind_of?( ::Array ) )
	  object = object.collect do | item |
	    save_value( kaivo, item, as_new )
	  end
	  owns_contents = ( kaivo.object( predicate, "subject_is_owner" ) == "true" )
	  object = Array::to_value( kaivo, object, owns_contents )
	else
	  object = save_value( kaivo, object, as_new )
	end

	kaivo.add( @value, predicate, object )
      end

      return @value
    end

    def save_value kaivo, value, as_new
      if( value.kind_of?( ObservableHash ) )
	value.save( kaivo, as_new )
	value.value
      else
	value
      end
    end
    
    def to_s
      @value
    end

  end
end
