require 'kaivo/valuelist'

module Kaivo
  class Value

    attr_reader :value

    def initialize value, kaivo
      @value = value
      @kaivo = kaivo
    end

    def property predicate
      Value.new( @kaivo.object( @value, predicate) )
    end

    def set_property predicate, object
      object = object.value if( object.kind_of?( Value ) )
      @kaivo.set_object( @value, predicate, object )
    end

    def add_observer observer
      @kaivo.add_observer( @value, nil, nil, observer )
    end

    def remove_observer observer
      @kaivo.remove_observer( @value, nil, nil, observer )
    end


    def export_with_owned_values kaivo
      export( kaivo, @value )
      @kaivo.owned_values( @value ).each do | owned_value |
      end
      
    end

    def export kaivo, target_value
      kaivo.remove_references_from( target_value )
      @kaivo.find( @value, nil, nil ).each do | statement |
	kaivo.add( target_value, statement.predicate, statement.object )
      end
    end

  end
end
