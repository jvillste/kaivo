require 'kaivo/index'
require 'kaivo/query'
require 'kaivo/classindex'

module Kaivo
  class ClassIndexCatalogue < Index
    def initialize environment, kaivo, transient
      super( environment, nil, false, transient )

      @transient = transient
      @kaivo = kaivo

      @open_indexes = Hash.new

      load_index_definitions()

    end

    def close
      @open_indexes.values.each do | index | index.close end
      super()
    end

    def classify subject
      return @kaivo.find( subject, "type", nil, 0, false ).collect do | statement | statement.object end
    end

    def predicate_indexed? subject, predicate

      return false if not @all_predicates.include?( predicate )

      return false if class_of_predicate( subject, predicate ).nil?

      return true

    end

    def class_of_predicate subject, predicate
      classify( subject ).each do | class_name |
	predicates = @predicates_by_class[ class_name ]
	if( not predicates.nil? )
	  if( predicates.include?( predicate ) )
	    return class_name
	  end
	end
      end

      return nil
    end

    def load_index_definitions
      @predicates_by_class = Hash.new
      @all_predicates = Set.new

      classes = nil
      predicate_sets = nil
      Transaction::in_current_transaction( @environment ) do | transaction |
#	classes = transaction.associate( self )[ "class_names" ]
	classes = @handle[ "class_names" ]
	if( not classes.nil? )
	  classes = classes.split( DELIMITER )
#	  predicate_sets = transaction.associate( self )[ "predicate_sets" ].split( SET_DELIMITER )
	  predicate_sets = @handle[ "predicate_sets" ].split( SET_DELIMITER )
	  predicate_sets = predicate_sets.collect do | set | set.split( DELIMITER ) end

	  classes.each_index do | index |
	    @predicates_by_class[ classes[ index ] ] = predicate_sets[ index ]
	    @all_predicates.merge( predicate_sets[ index ] )
	  end

	end
      end
    end

    def save_index_definitions
      Transaction::in_current_transaction( @environment ) do | transaction |
	predicate_sets = ""
	class_names = ""
	@predicates_by_class.keys.each do | class_name |
	  class_names += class_name + DELIMITER
	  predicate_sets += @predicates_by_class[ class_name ].inject do | set, predicate | set + DELIMITER + predicate end + SET_DELIMITER
	end
#	transaction.associate( self )[ "class_names" ] = class_names
	@handle[ "class_names" ] = class_names
#	transaction.associate( self )[ "predicate_sets" ] = predicate_sets
	@handle[ "predicate_sets" ] = predicate_sets
      end
    end

    def add_index class_name, predicates
      if( @predicates_by_class.has_key?( class_name ) )
	raise Exception.new( "Class index for " + class_name + " allready exists." )
      end

      @predicates_by_class[ class_name ] = predicates
      @all_predicates.merge( predicates )
      save_index_definitions()
    end

    def remove_index class_name
      index( class_name ).destroy
      @open_indexes.delete( class_name )


      @predicates_by_class.delete( class_name )
      @all_predicates.clear
      @predicates_by_class.values.each do | predicates |
	    @all_predicates.merge( predicates )
      end

      save_index_definitions()
    end
    
    def name
      return "_class_index_catalogue"
    end

    def index class_name
      if not @predicates_by_class.has_key?( class_name )
	raise Exception.new("There is no class index for class: " + class_name.to_s )
      end

      if not @open_indexes.include?( class_name )
	@open_indexes[ class_name ] = ClassIndex.new( @environment, class_name, @predicates_by_class[ class_name ], @transient )
      end
      return @open_indexes[ class_name ]
    end

    def find subject, predicate, object, partial_match, receiver
      return false if @predicates_by_class.keys.size == 0

      enough = false

      Transaction::join_current_transaction( @environment )

      if( predicate.nil? )
	class_names = classify( subject )
	class_names.each do | class_name |
	  next if( not @predicates_by_class.has_key?(class_name) )

	  @predicates_by_class[class_name].each do | predicate |
	    enough = index( class_name ).find( subject, predicate, object, partial_match, receiver )
	    break if enough
	  end

	  break if enough
	end
      else
	enough = index( class_of_predicate( subject, predicate )).find( subject, predicate, object,
								       partial_match, receiver )
      end

      Transaction::leave_current_transaction()

      return enough
    end

    def add_record class_name, statements
      discarded_statements = nil

      Transaction::in_current_transaction( @environment ) do | transaction |
	discarded_statements = index( class_name ).add_record( statements )
      end

      return discarded_statements
    end

    def add_statement statement
      Transaction::in_current_transaction( @environment ) do | transaction |
	index( class_of_predicate( statement.subject, statement.predicate ) ).add_statement( statement )
      end
    end

    def remove_statement statement
      Transaction::in_current_transaction( @environment ) do | transaction |
	index( class_of_predicate( statement.subject, statement.predicate ) ).remove_statement( statement )
      end
    end

  end
end
