require 'kaivo/statement'
require 'kaivo/forwardindex'
require 'kaivo/reverseindexcatalogue'
require 'kaivo/classindexcatalogue'
require 'kaivo/transaction'
require 'kaivo/value'
require 'kaivo/kaivo'

require 'set'
require 'date'
require 'bdb'
require 'thread'



module Kaivo
  class BDBKaivo < Kaivo
    
    def open_database transient

      creating_new_database = false
      if( not FileTest::exists?(@database_directory) )
	puts "creating new database " + @database_directory
	Dir::mkdir(@database_directory)
	creating_new_database = true
      end

#      @environment = BDB::Env.new(@database_directory , BDB::CREATE  | BDB::INIT_TRANSACTION | BDB::RECOVER, 0,
      @environment = BDB::Env.new(@database_directory , BDB::CREATE | BDB::INIT_MPOOL | BDB::INIT_LOG, 0,
				  #				  "set_lg_dir" => @log_directory,
				  "set_lk_max_locks" => 11000, "set_lk_max_objects" => 11000,
				  "set_lg_bsize" => 5 * 1024 * 1024, "set_cache_size" => [0, 5 * 1024 * 1024, 0] )



#      @environment.recover do | txn, id | puts "abort "; txn.abort end

      join_current_transaction()

      @forward_index = ForwardIndex.new( @environment, transient )
      @reverse_index_catalogue = ReverseIndexCatalogue.new( @environment, transient )
      @class_index_catalogue = ClassIndexCatalogue.new( @environment, self, transient )

      leave_current_transaction()

#       if(creating_new_database)
# 	from = ::Kaivo::Kaivo.new('base', '/home/jukka/src/ruby/kaivo/base')
# 	from.find(nil, nil, nil ).each do | statement |
# 	  add( statement.subject, statement.predicate, statement.object )
# 	end

# 	add( 'lens_parts', 'subject_is_owner', 'true' )
# 	add( 'value_view_lens', 'subject_is_owner', 'true' )
# 	add( 'value_view_container_lens', 'subject_is_owner', 'true' )

# 	from.shut_down()


#       end

      super()
    end

    def clear_logs
#      @environment.checkpoint(0)
      @environment.log_archive.each do | log_file_name |
	File.delete( @database_directory + "/" + log_file_name ) # @log_directory
      end
    end

    def close_database
      #      write_last_generated_value_to_database()
      clear_logs()
      @forward_index.close()
      @reverse_index_catalogue.close()
      @class_index_catalogue.close()
      @environment.close()
      
      puts "database " + @name + " closed"
    end


    ## Querying


    def count subject, predicate, object, partial_match = false

      if( subject.nil? and
	 ( not predicate.nil? ) and
	 ( not object.nil? ) and
	 @reverse_index_catalogue.predicate_indexed?( predicate ) and
	 not partial_match )
	return @reverse_index_catalogue.count( predicate, object )
      end

      n = 0
      generate( subject, predicate, object, partial_match, proc do | s, p, o, id | n += 1; false end )
      return n
    end

    def generate subject, predicate, object, partial_match, receiver, reverse_order = false

      enough = false

      join_current_transaction()

      if( not subject.nil? )
	if( predicate.nil? or
	   ( not predicate.eql?( "type" ) and @class_index_catalogue.predicate_indexed?( subject, predicate ) ) )
	  enough = @class_index_catalogue.find( subject, predicate, object, partial_match, receiver )
	end
	
	if( not enough )
	  enough = @forward_index.find( subject, predicate, object, partial_match, receiver, reverse_order )
	end

	if( not predicate.nil? and not enough)
	  enough = apply_function( subject, predicate, receiver )
	end

      else
	if( predicate.nil? and object.nil? )
	  enough = @forward_index.find( nil, nil, nil, true, receiver, reverse_order )
	elsif( predicate.nil? or @reverse_index_catalogue.predicate_indexed?( predicate ) )
	  enough = @reverse_index_catalogue.find( predicate, object, partial_match, receiver, reverse_order )
	end
      end

      leave_current_transaction()

      return enough
    end

     def incoming_predicates objects
       result = Set.new

       objects.each do | object | 
 	result.merge( @reverse_index_catalogue.incoming_predicates( object ) )
       end

       @source_kaivos.each do | source |
	 result.merge( source.incoming_predicates( objects ) )
       end

       result.merge( @static_source_kaivo.incoming_predicates( objects ) ) if( not @static_source_kaivo.nil? )


       return result

     end

    ## Modifying

    def add_to_database statement
      if( statement.subject == 'x' )
	puts "adding to " + @name + " : " + statement.to_s
      end

      join_current_transaction()

      if @class_index_catalogue.predicate_indexed?( statement.subject, statement.predicate )
	@class_index_catalogue.add_statement( statement )
      else
	@forward_index.add_statement( statement )
      end
      if( @reverse_index_catalogue.predicate_indexed?( statement.predicate ) )
	@reverse_index_catalogue.add_statement( statement )
      end

      leave_current_transaction()

      @environment.log_flush()
    end

    def remove_from_database statement
      join_current_transaction()

      if @class_index_catalogue.predicate_indexed?( statement.subject, statement.predicate )
	@class_index_catalogue.remove_statement( statement )
      else
    	@forward_index.remove_statement( statement )
      end
      if( @reverse_index_catalogue.predicate_indexed?( statement.predicate ) )
	@reverse_index_catalogue.remove_statement( statement )
      end

      leave_current_transaction()

      @environment.log_flush()
    end


    def add_records record_generator

      join_current_transaction()

      record_statements = []
      record_subject = ""
      record_subject_type = nil
      n = 0
      record_generator.call( proc do | subject, predicate, object |

			      if( not record_subject.eql?( subject ) )
				if( record_statements.size > 0 )
				  discarded_statements = @class_index_catalogue.add_record( record_subject_type, record_statements )
				  discarded_statements.each do | discarded_statement |
				    @forward_index.add_statement( discarded_statement )
				  end
				end
				record_subject = subject
				record_statements = []
			      end


			      statement_id = generate_value(false)
			      statement = Statement.new(  subject, predicate, object, statement_id  )

			      if( @reverse_index_catalogue.predicate_indexed?( statement.predicate ) )
				@reverse_index_catalogue.add_statement( statement )
			      end

			      record_statements << statement
			      record_subject_type = object if( predicate.eql?("type") )

			      n += 1
			      if( n.eql?(900) )
				n = 0
				write_last_generated_value_to_database()
				leave_current_transaction()
				clear_logs()
				join_current_transaction()
			      end

			    end )


      if( record_statements.size > 0 )
	discarded_statements = @class_index_catalogue.add_record( record_subject_type, record_statements )
	discarded_statements.each do | discarded_statement |
	  @forward_index.add_statement( discarded_statement )
	end
      end

      write_last_generated_value_to_database()
      leave_current_transaction()

    end


    # indexes

    def reverse_indexed? predicate
      @reverse_index_catalogue.predicate_indexed?( predicate )
    end

    def deny_reverse_index predicate
      @reverse_index_catalogue.deny_index( predicate )
    end

    def allow_reverse_index predicate
      @reverse_index_catalogue.allow_index( predicate )
    end

    def add_class_index class_name, predicates
      @class_index_catalogue.add_index( class_name, predicates )
    end

    def remove_class_index class_name
      @class_index_catalogue.remove_index( class_name )
    end

    ## Transactions

    def begin_transaction
      Transaction.new( @environment )
    end

    def join_current_transaction
      Transaction::join_current_transaction( @environment )
    end

    def leave_current_transaction
      Transaction::leave_current_transaction( @environment )
    end

    def call_in_transaction( transaction, method_symbol, *args )
      result = nil

#      puts 'call in transaction ' + method_symbol.to_s

      if( Transaction::get_thread_transaction( Thread.current, @environment ) == transaction )
	result = method( method_symbol ).call( *args )
      elsif( Transaction::get_thread_transaction( Thread.current, @environment ).nil? )
	Transaction::set_thread_transaction( Thread.current, transaction )
	result = method( method_symbol ).call( *args )
	Transaction::remove_thread_transaction( Thread.current, @environment )
      else
	thread = Thread.new do
	  Transaction::set_thread_transaction( Thread.current, transaction )
	  result = method( method_symbol ).call( *args )
	end
	thread.join
      end

      return result
    end


  end
end

