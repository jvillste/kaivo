require 'set'

module Kaivo
  class Transaction
    attr_reader :handle, :environment

    @@open_transactions = Set.new

    def Transaction::set_thread_transaction thread, transaction
      transactions = thread.instance_variable_get(:@transactions)
      if( transactions.nil? )
	transactions = Hash.new
	thread.instance_variable_set( :@transactions, transactions )
      end
      transactions[transaction.environment] = transaction
    end

    def Transaction::remove_thread_transaction thread, environment
      transactions = thread.instance_variable_get(:@transactions)
      transactions[environment] = nil
    end
    
    def Transaction::in_transaction? thread, environment
      not thread.instance_variable_get(:@transactions)[environment].nil?
    end

    def Transaction::get_thread_transaction thread, environment
      transactions = thread.instance_variable_get(:@transactions)
      if( transactions.nil? )
	return nil
      else
	return transactions[environment]
      end
    end


    def Transaction::in_current_transaction environment
      transaction = Transaction::join_current_transaction( environment )

      yield( transaction )

      Transaction::leave_current_transaction( environment )
    end

    def Transaction::join_current_transaction environment

      transaction = Transaction::get_thread_transaction( Thread.current, environment )

      if( transaction.nil? )
	transaction = Transaction.new( environment )
	Transaction::set_thread_transaction( Thread.current, transaction )
      else
	transaction.join
      end

      return transaction

    end

    def Transaction::leave_current_transaction environment
      transaction = Transaction::get_thread_transaction( Thread.current, environment )
      if( not transaction.nil? )
	if( transaction.leave() )
	  Transaction::remove_thread_transaction( Thread.current, transaction.environment )
	end
      end
    end

    def join
      @reference_count += 1
#      puts "join " + self.object_id.to_s + " " + @reference_count.to_s
#      puts caller[2 .. 4]
    end

    def leave
      @reference_count -= 1
#      puts "leave " + self.object_id.to_s + " " + @reference_count.to_s
#      puts caller[2 .. 4]
      if( @reference_count == 0 )
	commit()
	return true
      else
	return false
      end
    end

    def initialize environment
      @environment = environment
#      @handle = @environment.begin
      @index_handles = Hash.new
      @reference_count = 1

      @@open_transactions.add( self )
#      puts "new transaction " + object_id.to_s + " now open " +  @@open_transactions.size.to_s
#      puts caller[2 .. 4]
    end

    def commit
#      @handle.commit

      @@open_transactions.delete( self )
#      puts "commit transaction " + object_id.to_s + " now open " +  @@open_transactions.size.to_s
#      puts caller[2 .. 4]
    end

    def associate index
      return nil if @committed

      index_handle = @index_handles[index.name]
      if( index_handle.nil? )
	index_handle = @handle.associate( index.handle )
	@index_handles[index.name] = index_handle
      end
      return index_handle
    end
    
  end
end
