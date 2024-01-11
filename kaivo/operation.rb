module Kaivo
  class Operation
    attr_reader :value, :parameters

    def initialize value
      @value = value
    end

    def add_parameter predicate, type
    end

    def from_value
    end

    def to_value
    end

    def execute application
    end
    
  end
end
