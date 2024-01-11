require 'kaivo/value'

module Kaivo
  class ValueList

    def initialize values, kaivo
      @values = values
      @kaivo = kaivo
    end

    def to_a
      return @values
    end

    def concat value_list
      @values.concat( value_list.to_a )
    end

    def object predicate
      result = ValueList.new( [], @kaivo )

      @values.each do | value |
	result.concat( value.object( predicate ) )
      end

      return result
    end

    def subject predicate
      result = ValueList.new( [], @kaivo )

      @values.each do | value |
	result.concat( value.subject( predicate ) )
      end

      return result
    end


    def to_s
      result = ""
      @values.each do | value |
	result += value.value + ", "
      end
      if(not result == "")
	result.chop!().chop!()
      end
      return result
    end

  end
end

