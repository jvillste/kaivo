require 'kaivo'
require 'kaivo/index'

module Kaivo
  class ReverseIndex < Index

    def ReverseIndex::make_name predicate
      return "reverse_index_" + predicate
    end

    def initialize environment, predicate, comparator, transient
      @predicate = predicate

      super( environment, comparator, true, transient )
    end

    def name
      return ReverseIndex::make_name( @predicate )
    end

    def remove_statement statement
      Transaction::in_current_transaction( @environment ) do | transaction |
#	cursor = transaction.associate( self ).cursor
	cursor = @handle.cursor
	kv = cursor.get( BDB::GET_BOTH, statement.object, Index::make_record( [ statement.subject, statement.statement_id ] ) )
	cursor.delete if( not kv.nil? )
	cursor.close
      end
    end

    def add_statement statement

      if(statement.subject.nil? )
	raise Exception.new( "subject nil" )
      end

      Transaction::in_current_transaction( @environment ) do | transaction |
#	transaction.associate( self )[ statement.object ] = Index::make_record( [ statement.subject, statement.statement_id ] )
	@handle[ statement.object ] = Index::make_record( [ statement.subject, statement.statement_id ] )
      end
    end

    def count object
      count = nil
      Transaction::in_current_transaction( @environment ) do | transaction |
#	count = transaction.associate( self ).count( object )
	count = @handle.count( object )
      end
      return count
    end

    def find( object, partial_match, receiver, reverse_order = false )
      if object.eql?("")
	return false
      end

      transaction = Transaction::join_current_transaction( @environment )
#      cursor = transaction.associate( self ).cursor
      cursor = @handle.cursor
      kv = nil
      if( object.nil? and not reverse_order )
	kv = cursor.get( BDB::FIRST )
      elsif( object.nil? )
	kv = cursor.get( BDB::LAST )
      elsif( partial_match )
	kv = cursor.get( BDB::SET_RANGE, object )
      else
	kv = cursor.get( BDB::SET, object )
      end
      if kv.nil?
	cursor.close
	Transaction::leave_current_transaction( @environment )
	return false
      end

      begin
	parts = kv[1].split( DELIMITER )
	if partial_match
	  break if( not object.nil? and not ::Kaivo::string_begins_with?( kv[0], object) )
	else
	  break if( not object.nil? and not object.eql?( kv[0] ) )
	end

	if( receiver.call( Statement.new(parts[0], @predicate, kv[0], parts[1] ) ) )
	  cursor.close
	  Transaction::leave_current_transaction( @environment )
	  return true
	end

	if( object.nil? and reverse_order )
	  kv = cursor.get(BDB::PREV)
	else
	  kv = cursor.get(BDB::NEXT)
	end
      end while( not kv.nil? )

      cursor.close
      Transaction::leave_current_transaction( @environment )
      return false
    end


  end
end
