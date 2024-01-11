require 'kaivo/index'
require 'kaivo'
require 'kaivo/statement'

module Kaivo
  class ClassIndex < Index

    def initialize environment, class_name, predicates, transient
      @class_name = class_name
      @predicates = predicates
      
      super( environment, nil, false, transient )
    end

    def name
      return "class_index_" + @class_name
    end

    def remove_statement statement
      Transaction::in_current_transaction( @environment ) do | transaction |

	record = transaction.associate( self )[ statement.subject ]

	match = Regexp.new( '(' + DELIMITER + ')?' + statement.object + DELIMITER +
			   statement.statement_id + '(' + DELIMITER + ')?' ).match( record )

	return if match.nil?

	if( not match[1].nil? and not match[2].nil? )
	  transaction.associate( self )[ statement.subject ] = record.sub(match[0], DELIMITER)
	else
	  transaction.associate( self )[ statement.subject ] = record.sub(match[0], "")
	end

      end
    end

    def add_record statements
      return if statements.size == 0
      
      discarded_statements = []
      
      subject = statements[0].subject

      value_sets = @predicates.collect do | predicate | [] end

      statements.each do | statement |
	index = @predicates.index( statement.predicate )
	if not index.nil?
	  value_sets[index] << statement.object
	  value_sets[index] << statement.statement_id
	else
	  discarded_statements << statement
	end
      end

      record_sets = value_sets.collect do | value_set |
	if( value_set.size > 0 )
	  value_set.inject do | record_set, value |
	    record_set + DELIMITER + value end
	else
	  ""
	end
      end

      record = record_sets.inject do | record, record_set | record + SET_DELIMITER + record_set end

      Transaction::in_current_transaction( @environment ) do | transaction |
	transaction.associate( self )[ subject ] = record
      end

      return discarded_statements
    end

    def add_statement statement
      Transaction::in_current_transaction( @environment ) do | transaction |

	record = transaction.associate( self )[ statement.subject ]

	if( record.nil? )
	  record = SET_DELIMITER * ( @predicates.size - 1 )
	end

	match = Regexp.new( '((.*?' + SET_DELIMITER + '){' +
			   @predicates.index( statement.predicate ).to_s + '})(.*?)(' + SET_DELIMITER + '|$)(.*)' ).match( record )

	new_value = statement.object + DELIMITER + statement.statement_id

	new_set = match[3]

	return if not new_set.index( statement.statement_id ).nil?

	if( new_set.eql?("") )
	  new_set = new_value
	else
	  new_set += DELIMITER + new_value
	end

	transaction.associate( self )[ statement.subject ] = match[1] + new_set + match[4] + match[5]
      end
    end


    def find( subject, predicate, object, partial_match, receiver )
      record = nil

      Transaction::in_current_transaction( @environment ) do | transaction |
	record = transaction.associate( self )[ subject ]
      end

      return if record.nil?

      value_set = Regexp.new( '((.*?' + SET_DELIMITER + '){' +
			     @predicates.index( predicate ).to_s + '})(.*?)(' +
			     SET_DELIMITER + '|$)' ).match( record )[3].split( DELIMITER )

      value_set.each_index do | index |
	next if index.modulo( 2 ) > 0

	stored_object = value_set[index]

	if partial_match
	  next if( not object.nil? and not ::Kaivo::string_begins_with?( stored_object.downcase, object.downcase) )
	else
	  next if( not object.nil? and not object.eql?( stored_object ) )
	end
	
	if( receiver.call( subject, predicate, stored_object, value_set[index + 1] ) )
	  return true
	end
      end

      return false
    end
  end
end
