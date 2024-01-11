require 'bdb'

module Kaivo
  class Index

    attr_reader :handle

    DELIMITER = "£¡"

    SET_DELIMITER = '£#'

    def Index::case_insensitive_string_compare a, b
      a.downcase <=> b. downcase
    end

    def print_statistics
      Transaction::in_current_transaction( @environment ) do | transaction |
#	transaction.associate( self ).stat.each do |k, v|
	@handle.stat.each do |k, v|
	  print "#{k}\t#{v}\n"
	end
      end
    end

    def size
      size = nil
      Transaction::in_current_transaction( @environment ) do | transaction |
#	size = transaction.associate( self ).size
	size = @handle.size
      end
      return size
    end

    def Index::make_record fixed_values, partial_match = false
      record = ""

      fixed_values.delete_if do | value | value.nil? end

      fixed_values[0 .. -2].each do | fixed_value |
	record += fixed_value + DELIMITER
      end

      record += fixed_values[-1].to_s
      record += DELIMITER if not partial_match 

      return record
    end

    def Index::destroy environment, name
      puts "destroying " + name
      begin
      environment.dbremove( "kaivo.bdb", name, BDB::AUTO_COMMIT )
      rescue
      end
    end

    def close
      @handle.close
    end

    def destroy
      close()
      Index::destroy( @environment, name() )
    end

    def initialize environment, comparator, allow_duplicates, transient = false
      @environment = environment

      Transaction::in_current_transaction( @environment ) do | transaction |

	flags = { }
	if( not transient )
	  flags = { "env" => @environment } #, "txn" => transaction.handle }
	end

	options = BDB::CREATE

	if( allow_duplicates )
	  flags["set_flags"]= BDB::DUPSORT
	end

	if( not comparator.nil? )
	  flags["set_bt_compare"] = comparator
	end

	if( transient )
	  @handle = BDB::Btree.open( nil, nil, options, 0, flags )
	else
	  @handle = BDB::Btree.open( "kaivo.bdb", name(), options, 0, flags )
	end


      end

    end
  end
end
