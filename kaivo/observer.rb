module Kaivo
  class Observer

    def initialize procedure = nil
      @procedure = procedure
    end

    def set_procedure procedure
      @procedure = procedure
    end

    def update *args
      @procedure.call( *args ) if @procedure
    end
  end
end
