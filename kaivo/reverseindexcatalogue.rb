require 'kaivo/index'
require 'kaivo/reverseindex'
require 'set'

module Kaivo
  class ReverseIndexCatalogue < Index
    def initialize environment, transient
      super( environment, nil, false, transient )

      @transient = transient

      @predicates = Set.new
      @denied_predicates = Set.new

      @open_indexes = Hash.new

      Transaction::in_current_transaction( @environment ) do | transaction |
#	predicates = transaction.associate( self )[ "predicates" ]
	predicates = @handle[ "predicates" ]
	@predicates.merge( predicates.split( DELIMITER ) ) if not predicates.nil?
#	denied_predicates = transaction.associate( self )[ "denied_predicates" ]
	denied_predicates = @handle[ "denied_predicates" ]
	@denied_predicates.merge( denied_predicates.split( DELIMITER ) ) if not denied_predicates.nil?
      end

    end

    def close
      @open_indexes.values.each do | index | index.close end
      super()
    end

    def predicate_indexed?( predicate )
      return ( not @denied_predicates.include?( predicate ) )
    end

    def name
      return "_reverse_index_catalogue"
    end


    def load_index_definitions
      Transaction::in_current_transaction( @environment ) do | transaction |
#	@predicates.merge( transaction.associate( self )[ "predicates" ].split( DELIMITER ) )
	@predicates.merge( @handle[ "predicates" ].split( DELIMITER ) )
      end
    end

    def save_index_definitions
      Transaction::in_current_transaction( @environment ) do | transaction |
#	transaction.associate( self )[ "predicates" ] = @predicates.inject do | list, predicate |
	@handle[ "predicates" ] = @predicates.inject do | list, predicate |
	  list + DELIMITER +  predicate end

#	transaction.associate( self )[ "denied_predicates" ] = @denied_predicates.inject do | list, predicate |
	@handle[ "denied_predicates" ] = @denied_predicates.inject do | list, predicate |
	  list + DELIMITER +  predicate end
      end
    end

    def deny_index predicate
      return if @denied_predicates.include?( predicate )
      remove_index( predicate )

      @denied_predicates.add( predicate )
      save_index_definitions()
    end

    def allow_index predicate
      @denied_predicates.delete( predicate )
      save_index_definitions()
    end

    def remove_index predicate
      if not @open_indexes.include?( predicate )
	Index::destroy( @environment, ReverseIndex::make_name( predicate ) )
      else
	index( predicate ).destroy
	@open_indexes.delete( predicate )
      end

      @predicates.delete( predicate )
      save_index_definitions()
    end
    
    def index predicate
      if @denied_predicates.include?( predicate )
	return nil
      end

      if not @open_indexes.include?( predicate )
	if not @predicates.include?( predicate )
	  @predicates.add( predicate )
	  save_index_definitions()
	end
	@open_indexes[ predicate ] = ReverseIndex.new( @environment, predicate, nil, @transient ) # Index.method(:case_insensitive_string_compare)
      end
      return @open_indexes[ predicate ]
    end

    def incoming_predicates object
      result = Set.new
      Transaction::join_current_transaction( @environment )

      @predicates.each do | predicate |
	if( index( predicate ).find( object, false, proc do |statement| true end ) )
	  result.add( predicate )
	end
      end

      Transaction::leave_current_transaction( @environment )
      return result
    end

    def count predicate, object
      return index( predicate ).count( object )
    end


    def find predicate, object, partial_match, receiver, reverse_order = false
      if( predicate.nil? )
	@predicates.each do | predicate |
	  break if( index( predicate ).find( object, partial_match, receiver, reverse_order ) )
	end
      else
	index( predicate ).find( object, partial_match, receiver, reverse_order )
      end
    end

    def add_statement statement
      index( statement.predicate ).add_statement( statement )
    end

    def remove_statement statement
      index( statement.predicate ).remove_statement( statement )
    end

  end
end
