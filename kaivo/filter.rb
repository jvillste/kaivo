module Kaivo
  class Filter
    attr_accessor :filter_procedure

    def initialize receiver, filter_procedure
      @receiver = receiver
      @filter_procedure = filter_procedure
    end

    def receive value
      if @filter_procedure.call( value )
	return @receiver.call( value )
      else
	return false
      end
    end
    
  end
end
