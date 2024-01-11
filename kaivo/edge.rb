module Kaivo
  class Edge

    attr_reader :node, :from, :label, :to

    def initialize node, from, label, to
      @node = node
      @from = from
      @label = label
      @to = to
    end

    def hash
     (@node + @from + @label + @to).hash
    end

    def eql? edge
      @node == edge.node &&
      @from == edge.from &&
      @label == edge.label &&
      @to == edge.to
    end

    def to_s
      return @node + " : "  + @from + " - " +  @label  + " -> " + @to
    end

  end
end
