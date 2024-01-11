module Kaivo
  class Statement

    attr_accessor :statement_id, :subject, :predicate, :object, :source

    def initialize subject, predicate, object, statement_id, source = nil
      @statement_id = statement_id
      @subject = subject
      @predicate = predicate
      @object = object
      @source = source
    end

    def object= o
      @object = o
    end

    def hash
      @statement_id.hash
    end

    def eql? statement
      @statement_id == statement.statement_id
    end

    def to_s
      return @source.to_s + ' : ' + @statement_id.to_s + " : "  + @subject.to_s + " - " +  @predicate.to_s  + " -> " + @object.to_s
    end

  end
end
