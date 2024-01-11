require 'kaivo'

module Kaivo
  class Path
    attr_accessor :parts

    def initialize receiver, kaivo, parts
      @receiver = receiver
      @kaivo = kaivo
      @parts = parts
    end

    def Path.reverse_parts parts
      return parts.reverse.collect do | part |
	{ :predicate => part[:predicate],
	  :direction => part[:direction] == :object ? :subject : :object }
      end
    end

    def Path.exists? kaivo, source_value, path_parts, target_value, partial_match
      result = false
      path = Path.new(proc do | value |
			if partial_match
			  if ::Kaivo::string_begins_with?(value.downcase, target_value.downcase)
			    result = true
			    true
			  else
			    false
			  end
			else
			  if ::Kaivo::string_eql?(target_value.downcase,value.downcase)
			    result = true
			    true
			  else
			    false
			  end
			end
		      end,
		      kaivo,
		      path_parts )
      path.follow_path( source_value, path_parts )
      return result
    end

    def Path.ending kaivo, source_value, path_parts
      result = nil
      path = Path.new( proc do | value | result = value; true end,
		      kaivo,
		      path_parts )
      path.follow_path( source_value )
      return result
    end

    def Path.endings kaivo, source_value, path_parts
      result = Set.new
      path = Path.new( proc do | value | result.add(value); false end,
		      kaivo,
		      path_parts )
      path.follow_path( source_value )

      return result
    end

    def receive value
      if( follow_path( value ) )
	true
      else
	false
      end
    end

    def follow_path source_value, parts = @parts
      enough = false

      if parts.size == 0
	return @receiver.call( source_value )
      end

      @kaivo.join_current_transaction

	if( parts[0][:direction] == :object )

	  @kaivo.find( source_value, parts[0][:predicate], nil, 0, true, proc do | value |
				       if( parts.size > 1 )	
					 follow_path( value.object,  parts[1 .. -1] )
				       else
					 enough = @receiver.call( value.object )
					 enough
				       end
				     end )

	else

	  @kaivo.find( nil, parts[0][:predicate], source_value, 0, true, proc do | value |
				       if( parts.size > 1 )	
					 follow_path( value.subject,  parts[1 .. -1] )
				       else
					 enough = @receiver.call( value.subject )
					 enough
				       end
				     end )
	end

      @kaivo.leave_current_transaction

      return enough
    end

  end
end

