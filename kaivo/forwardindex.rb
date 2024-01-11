require 'kaivo/index'
require 'kaivo'

module Kaivo
  class ForwardIndex < Index

    def initialize environment, transient
      super( environment, nil, false, transient )
    end

    def name
      "forward_index"
    end

    def remove_statement statement
      Transaction::in_current_transaction( @environment ) do | transaction |
#	cursor = transaction.associate( self ).cursor
      cursor = @handle.cursor

	kv = cursor.get( BDB::SET, Index::make_record( [ statement.subject,
							statement.predicate,
							statement.object,
							statement.statement_id ] ) )
	cursor.delete if( not kv.nil? )
	cursor.close
      end
    end

    def add_statement statement
      Transaction::in_current_transaction( @environment ) do | transaction |

	if( statement.subject.nil? or statement.predicate.nil? or statement.object.nil? or statement.statement_id.nil? )
	  throw Exception.new( "Trying to add invalid statement: " + statement.to_s )
	end

	#transaction.associate( self )[ Index::make_record(  [ statement.subject,
	@handle[ Index::make_record(  [ statement.subject,
							    statement.predicate,
							    statement.object,
							    statement.statement_id ] ) ] = ""
      end
    end

    def find( subject, predicate, object, partial_match, receiver, reverse_order = false )
      enough = false
      transaction = Transaction::join_current_transaction( @environment )

      cursor = nil
#      if( in_transaction )
#	cursor = transaction.associate( self ).cursor
#      else
	cursor = @handle.cursor
#      end

      if( subject.nil? and predicate.nil? and object.nil? )
	partial_match = true
      elsif( object.nil? )
	partial_match = false
      end

      kv = nil
      record = Index::make_record(  [ subject,
				     predicate,
				     object ],
				  partial_match )
      if( reverse_order and subject.nil? )
	record.next!
      end
      kv = cursor.get( BDB::SET_RANGE, record )


      if kv.nil?
	cursor.close
	Transaction::leave_current_transaction( @environment )
	return false
      end

      begin
	parts = kv[0].split( DELIMITER )

	if( partial_match )
	  break if( not object.nil? and not ::Kaivo::string_begins_with?( parts[2], object ) )
	else
	  break if( not object.nil? and not object.eql?( parts[2] ) )
	end

	break if( not predicate.nil? and not predicate.eql?( parts[1] ) )
	break if( not subject.nil? and not subject.eql?( parts[0] ) )
	enough = receiver.call( Statement.new(parts[0], parts[1], parts[2], parts[3] ) )
	break if( enough )

	if( reverse_order and subject.nil? )
	  kv = cursor.get(BDB::PREV)
	else
	  kv = cursor.get(BDB::NEXT)
	end
      end while( not kv.nil? )

      cursor.close
      Transaction::leave_current_transaction( @environment )

      return enough
    end

  end
end
