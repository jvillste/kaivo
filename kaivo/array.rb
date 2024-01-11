require 'kaivo/statement'

module Kaivo
  module Array
    def Array::to_value kaivo, array, owns_contents = false
      array_value = kaivo.generate_value()
      kaivo.add( array_value, "type", "Array" )

      array.each_index do | index |
	statement_id = kaivo.add( array_value, "array_index_" + index.to_s, array[index] )
	kaivo.add( statement_id, "subject_is_owner", "true" ) if owns_contents
      end
      
      return array_value
      
    end

    def Array::from_value kaivo, array_value
      array = []
      return array if array_value.nil?

      kaivo.find( array_value, nil, nil).each do | statement |
	match = /array_index_(\d*)/.match(statement.predicate)
	if( match != nil )
	  array[match[1].to_i] = statement.object
	end
      end
      return array
    end

    def Array::clear kaivo, array_value
      kaivo.find( array_value, nil, nil).each do | statement |
	if( ( statement.predicate =~ /array_index_\d*/ ) != nil )
	  kaivo.remove( statement.statement_id )
	end
      end
    end
    
  end
end
