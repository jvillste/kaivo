require 'kaivo/filter'
require 'kaivo/path'

module Kaivo
  class Query

    attr_accessor :skip

    def initialize
      @constraints = []
      @sortings = []
      @skip = 0
    end

    def add_constraint path, value, partial_match = true
      @constraints << { :path => path, :value => value, :partial_match => partial_match }
    end

    def add_sorting path, direction
      @sortings << { :path => path, :direction => direction }
    end

    def choose_generator candidates, kaivo
      candidates.each do | candidate |
	if( candidate[:path].size > 0 and
	   kaivo.reverse_indexed?( candidate[:path][-1][:predicate] ) and
	   not kaivo.is_function?( candidate[:path][-1][:predicate] ) )

	  candidate[:path] = Path::reverse_parts( candidate[:path] )
	  candidates.delete( candidate )
	  return candidate
	end
      end

      return nil
    end

    def run kaivo, receiver = nil
      return [] if @constraints.size == 0

      result = []

      ## choose generator

      generator = choose_generator( @sortings, kaivo )

      if( generator.nil? )
	generator = choose_generator( @constraints, kaivo )
      end

      if( generator.nil? )
	generator = @constraints[0]
      end



      kaivo.join_current_transaction

      if receiver.nil?
	receiver = proc do | value | result << value; false end
      end
      
      final_receiver = receiver

      if( @skip > 0)
	n = 0
	receiver = proc do | value |
	  n += 1
	  if( @skip > n)
	    false
	  else
	    final_receiver.call( value )
	  end
	end
      end

      ## add sorting

#      final_receiver = receiver
#      filtered_values = []
#      if( @sortings.size > 0 )
#	receiver = proc do | value | filtered_values << value; false end
#      end

      ## add filters

      @constraints.each do | constraint |
	filter = Filter.new(receiver,
			    proc do | value |
			      Path.exists?( kaivo,
					   value,
					   constraint[:path],
					   constraint[:value],
					   constraint[:partial_match] )
			    end)
	
	receiver = filter.method(:receive)
      end

      ## run generator

      generator_path = Path.new( receiver,
				kaivo,
				generator[:path][1 .. -1] )
      
      reverse_order = ( generator[:direction] == :descending )

      if( generator[:path][0][:direction] == :subject )

	kaivo.find2( { :predicate => generator[:path][0][:predicate],
		      :object => generator[:value],
		      :partial_match => generator[:partial_match],
		      :receiver => proc do | statement |
			generator_path.receive( statement.subject )
		      end,
		      :reverse_order => reverse_order } )
      else

	kaivo.find2( { :predicate => generator[:path][0][:predicate],
		      :subject => generator[:value],
		      :partial_match => generator[:partial_match],
		      :receiver => proc do | statement |
			generator_path.receive( statement.object )
		      end,
		      :reverse_order => reverse_order } )

      end


      ## run sorting

#       if( @sortings.size > 0 )
# 	filtered_values = filtered_values.collect do | value |
# 	  sort_value = ""
# 	  @sortings.each do | sorting |
# 	    sort_value += Path.ending( kaivo, value, sorting[:path] ).to_s
# 	  end

# 	  float_value = nil
# 	  begin
# 	    float_value = Float(sort_value)
# 	  rescue Exception => e
# 	  end
# 	  if not float_value.nil?
# 	    sort_value = float_value
# 	  else
# 	    sort_value = sort_value.downcase 
# 	  end

# 	  [sort_value, value ]
# 	end.sort do | value_pair_1, value_pair_2 |
# 	  result = 0
# 	  if( value_pair_1[0].instance_of?(Float) and value_pair_2[0].instance_of?(Float) )
# 	    result = value_pair_2[0] <=> value_pair_1[0]
# 	  else
# 	    result = value_pair_2[0].to_s.unpack('U*') <=> value_pair_1[0].to_s.unpack('U*')
# 	  end
# 	  result = - result if( @sortings[0][:direction].eql?( :descending ) )
# 	  result
# 	end.collect do | value_pair |
# 	  value_pair[1]
# 	end

# 	filtered_values.each do | value |
# 	  break if( final_receiver.call( value ) )
# 	end
#       end

      kaivo.leave_current_transaction

      return result
    end
  end
end
