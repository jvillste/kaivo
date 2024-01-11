require 'kaivo/statement'
require 'kaivo/observer'
require 'rdf/redland'
require 'uri'
require 'open-uri'

require 'set'

Dir.glob( './plugins/*.rb' ).each do | plugin |
  require plugin
end


module Kaivo
  class Kaivo

    attr_reader :name, :environment

    def initialize name, database_directory = nil, transient = false
      puts "opening " + name

      @name = name

      @source_kaivos = []

      @static_sources = Hash.new

      #      @base_kaivo = Kaivo.new('base', ') if( not @name == 'base' )


      #      @database_directory = "/tmp/ramdisk"
      if( database_directory.nil? )
	@database_directory = @name
      else
	@database_directory = database_directory
      end

      #      @number_of_observers = 0
      #      @number_of_statement_observers = 0
      @observers = Hash.new
      @statement_observers = Hash.new

      open_database( transient )

      objects('kaivo', 'Kaivo#rdf_xml_source' ).each do | source_url |
	add_static_source( source_url, 'rdfxml' )
      end

      add_observer( 'kaivo', 'Kaivo#rdf_xml_source', nil, Observer.new( proc do | statement, change_type |
									   case change_type
									   when :add
									     add_static_source( statement.object, 'rdfxml' )
									   when :remove
									     remove_static_source( statement.object )
									   end
									 end ) )

      objects('kaivo', 'Kaivo#static_kaivo_source' ).each do | source_url |
	add_static_source( source_url, 'kaivo' )
      end

      add_observer( 'kaivo', 'Kaivo#static_kaivo_source', nil, Observer.new( proc do | statement, change_type |
									   case change_type
									   when :add
									     add_static_source( statement.object, 'kaivo' )
									   when :remove
									     remove_static_source( statement.object )
									   end
									 end ) )

      @load_related_rdf_sources = object('kaivo', 'Kaivo#load_related_rdf_sources') == 'true'
      add_observer( 'kaivo', 'Kaivo#load_related_rdf_sources', nil, Observer.new( proc do | statement, change_type |
									 @load_related_rdf_sources = ( statement.object == 'true' )
								       end ) )
      puts "done."
    end

    def strip_url url
      match = url.match(/(.*)#/)

#      if( match.nil? )
#	match = url.match(/(.*)\//)
#      end

      if( not match.nil? )
	url = match[1]
      end

      return url
    end

    def add_static_source url, format

      if( url.match(/.*\.(rdf|xml|kaivo)$/).nil? )
	url = strip_url( url )
      end

      @static_source_kaivo = BDBKaivo.new( @name + '/static', nil, true ) if @static_source_kaivo.nil?
      return if @static_sources.include?( url )
      @static_sources[ url ] = true

      begin
	uri = URI::parse( url )
	return if( uri.scheme != 'http' and uri.scheme != 'file' )
      rescue Exception => e
	return
      end

      case format
      when 'rdfxml'
	@static_source_kaivo.import_rdf_xml( url )
      when 'kaivo'
 	@static_source_kaivo.import( url )
      end

    end

    def remove_static_source source_url
#      @source_kaivos.delete_if do | source | source.name == source_url end
    end

    def print_statistics
      puts 'forward index size ' + @forward_index.size.to_s
      puts "\ntransaction statistics"
      @environment.txn_stat.each do |k, v|
	print "#{k}\t#{v}\n"
      end
      puts "\nlocking statistics"
      @environment.lock_stat.each do |k, v|
	print "#{k}\t#{v}\n"
      end
      puts "\nforward index statistics"
      @forward_index.print_statistics
    end

    def export file_name, excluded_values = []
      file = File.new(file_name, "w")
      delimiter = "!~"
      find( nil, nil, nil, 0, false, proc do | statement |
	     next if( excluded_values.include?(statement.subject) or  excluded_values.include?(statement.object) )
             file.puts( ( statement.subject + delimiter + statement.predicate + delimiter + statement.object ).gsub("\n",'~~') )
	     false
	   end )

      file.close()
    end

    def import url
      puts 'importing ' + url

      match = url.match(/^(file:\/\/)(.*)/)
      if( not match.nil? )
	url = match[2]
      end

      open(url) do |file|
	add_many( proc do | receiver |

		   file.each_line do | line |
		     line = line.strip
		     line = line.gsub('~~', "\n")
		     values = line.split( "!~" )
		     receiver.call( values[0].to_s, values[1].to_s, values[2].to_s )
		   end

		 end )
      end
    end

    def redland_node_to_string node, url

      if node.literal?
	node = node.value
      elsif node.blank?
	node = url + '/blank/' + node.blank_identifier.to_s
      elsif node.resource?
	node = node.uri.to_s
      end 

      return node
    end

    def import_rdf_xml url
      puts "importing " + url

      begin
	parser = Redland::Parser.new('rdfxml')
	parser.set_feature('http://feature.librdf.org/raptor-scanForRDF', '1')
	stream = parser.parse_as_stream(url, url)
	add_many( proc do | receiver |

		   while not stream.end?

#		     	          puts redland_node_to_string( stream.current.subject, url  ) + " " + 
#		     		            redland_node_to_string( stream.current.predicate,  url )#   + " " +
#		     		            redland_node_to_string( stream.current.object,  url )

		     receiver.call( redland_node_to_string( stream.current.subject, url ),
				   redland_node_to_string( stream.current.predicate, url ),
				   redland_node_to_string( stream.current.object, url ) )
		     stream.next
		   end

		 end,

		 true)



      rescue  Exception => e
	puts "Import failed for " + url.to_s + " : " + e.message
      end


    end

    def add_source source_kaivo
      @source_kaivos << source_kaivo
    end

    def shut_down
      close_database()
      system('rm ' + @name + '/static/*') if( FileTest::exists?(@name + '/static') )

      @static_source_kaivo.shut_down if( not @static_source_kaivo.nil? )

#      @source_kaivos.each do | source | source.shut_down end

    end


    def generate_value write_to_database = true

      @last_generated_value += 1

      write_last_generated_value_to_database() if write_to_database
      #      puts "generated " + @name + "_" + @last_generated_value.to_s
      #      puts caller[0 .. 2]
      return @name + "#" + @last_generated_value.to_s
    end

    def write_last_generated_value_to_database

      remove_pattern( "kaivo", "last_generated_value", nil )

      add_to_database( Statement.new("kaivo",
				     "last_generated_value",
				     @last_generated_value.to_s,
				     "last_generated_value_statement",
				     @name) )
    end

    def create_plugin_instance class_name
      eval(class_name).new( self )
    end

    ## database modification

    def add_new subject, predicate, object
      join_current_transaction()

      statement_id = nil
      if( find( subject, predicate, object, 1, false ).size == 0 )
	statement_id = add( subject, predicate, object )
      end

      leave_current_transaction()

      return statement_id

    end

    def add subject, predicate, object
      if( subject.nil? or predicate.nil? or object.nil? )
	throw Exception.new("Trying to add invalid statement " + subject.to_s + "," + predicate.to_s + "," + object.to_s)
      end


      statement = nil
      statement_id = nil
      join_current_transaction()

      statement_id = generate_value()
      statement = Statement.new( subject, predicate, object, statement_id, @name )
      add_to_database( statement )

      leave_current_transaction()

      notify( statement, :add )

      if( predicate == 'type' )
	types(subject).each do | type |
	  constructor = object(type, 'Type#constructor')
	  if( not constructor.nil? )
	    begin
	      eval(constructor).call( self, subject )
	    rescue  Exception => e
	      puts "Constructor failed for " + type + " : " + e
	    end
	  end
	end
      end


      return statement_id
    end

    def add_many statement_generator, only_new = false
      statements = []


      join_current_transaction()

      n = 0
      statement_generator.call( proc do | subject, predicate, object |
				 next if( only_new and find( subject, predicate, object, 1, false ).size > 0 )

				 statement_id = generate_value(false)
				 statement = Statement.new(  subject, predicate, object, statement_id, @name  )

				 add_to_database( statement )

				 n += 1
				 if( n.eql?(900) )
				   puts statement.to_s
				   n = 0
				   write_last_generated_value_to_database()
				   leave_current_transaction()
				   
				   clear_logs()
				   join_current_transaction()
				 end
				 
			       end )

      write_last_generated_value_to_database()
      leave_current_transaction()

    end

    
    def remove statement

      return if( statement.source != @name )

      join_current_transaction()

      remove_from_database( statement )
      remove_value( statement.statement_id )

      leave_current_transaction()

      notify( statement, :remove )

    end

    def remove_pattern subject, predicate, object
      return if subject.nil? and predicate.nil? and object.nil?

      find( subject, predicate, object ).each do | statement |
	remove( statement )
      end
    end

    def remove_referrences_to value
      remove_pattern( nil, nil, value )
    end

    def remove_referrences_from value, domains = nil
      if( domains.nil? )
	remove_pattern( value, nil, nil )
      else
	find( value, nil, nil ).each do | statement |
	  remove( statement ) if domain_in_set?( domains, statement.predicate )
	end
      end
    end

    def remove_value value
      join_current_transaction()
      
      remove_referrences_to( value )
      remove_referrences_from( value )

      leave_current_transaction()
    end

    def remove_values_owned_by value
      directly_owned_values(value).each do | owned_value |
	remove_value_and_owned_values( owned_value )
      end
    end

    def directly_owned_values value, domains = nil
      result = Set.new
      find( value, nil, nil, 0, false ).each do | statement |
	if( domain_in_set?( domains, statement.predicate ) and subject_is_owner?( statement ) )
#	  puts statement.object + " is owned by " + value + " because " + statement.predicate
	  result.add( statement.object )
	end
      end
      return result
    end

    def remove_value_and_owned_values value, domains_of_removed_properties = nil
      return if value.nil?
      
      join_current_transaction()

      owned_objects = directly_owned_values( value, domains_of_removed_properties )

      shared_objects = Set.new
      owned_objects.each do | object |
	find( nil, nil, object, 0, false ).each do | statement |
	  if( subject_is_owner?( statement ) )
	    if( not value.eql?( statement.subject ) and not owned_objects.include?( statement.subject ) )
	      shared_objects.add( object )
	      break
	    end
	  end
	end
      end

      if( domains_of_removed_properties.nil? )
	remove_value( value )
      else
	remove_referrences_from( value, domains_of_removed_properties )
      end

      removeable_values = (owned_objects - shared_objects)
      removeable_values.each do | removeable_value  |
	remove_value_and_owned_values( removeable_value )
      end

      leave_current_transaction()

    end

    def set_object subject, predicate, object
      join_current_transaction()

      statement = find( subject, predicate, nil, 1 )[0]

      if( not statement.nil? )
	if( statement.source != @name )
	  leave_current_transaction()
	  return
	end

	set_statement_object( statement, object )
      else
	add( subject, predicate, object )
      end

      leave_current_transaction()
    end

    def set_statement_object statement, new_object
      return if( statement.source != @name )

      join_current_transaction()

      remove_from_database( statement )
      statement.object = new_object
      add_to_database( statement )

      leave_current_transaction()

      notify( statement, :object_change )
    end

    def set_statement_subject statement, new_subject
      return if( statement.source != @name )

      join_current_transaction()

      remove_from_database( statement )
      statement.subject = new_subject
      add_to_database( statement )
      
      leave_current_transaction()

      notify( statement, :object_change )
    end


    def duplicate value
      duplicated_value = generate_value()
      find( value, nil, nil ).each do | statement |
	add( duplicated_value, statement.predicate, statement.object )
      end
      return duplicated_value
    end


    ## querying

    def outgoing_statements_closure subject, statements = Set.new, visited_subjects = Set.new([""])

      visited_subjects.add( subject )

      find( subject, nil, nil, 0, false, proc do | statement |
	     statements.add( statement )

	     outgoing_statements_closure( statement.object, statements, visited_subjects ) if( not visited_subjects.include?( statement.object ) )
	     true
	   end )

      return statements

    end

    def find2 parameters
      parameters =
	{ :max => 0,
	:partial_match => false,
	:find_equal_predicates => true,
	:skip => 0,
	:reverse_order => false }.merge( parameters )

      find( parameters[:subject],
	   parameters[:predicate],
	   parameters[:object],
	   parameters[:max],
	   parameters[:partial_match],
	   parameters[:receiver],
	   parameters[:find_equal_predicates],
	   parameters[:skip],
	   parameters[:reverse_order] )
    end

    def find subject, predicate, object, max = 0, partial_match = false, receiver = nil, find_equal_predicates = true, skip = 0, reverse_order = false
      values = []

      if( @load_related_rdf_sources and ( not @loading_related_rdf_source ) )
	@loading_related_rdf_source = true
	add_static_source( subject, 'rdfxml' ) if not subject.nil?
	add_static_source( predicate, 'rdfxml' ) if not predicate.nil?
	@loading_related_rdf_source = false
      end


      source_name = @name

      n = 0
      transmitter = proc do | statement |
	return true if( n == ( max + skip ) and max > 0  )
	n += 1
	return false if skip >= n

	statement.source = source_name

	if( statement.statement_id.nil? )
	  puts "removing invalid statement!! " + statement.to_s
	  remove( statement )
	  next
	end

	values << statement

	return receiver.call( statement ) if not receiver.nil?
	return false
      end

      enough = generate( subject, predicate, object, partial_match, transmitter, reverse_order )

      if( not @static_source_kaivo.nil? and not enough )
	source_name = @static_source_kaivo.name
	@static_source_kaivo.generate( subject, predicate, object, partial_match, transmitter, reverse_order )
      end

      
      if( find_equal_predicates )
	equal_predicates( predicate ).each do | equal_predicate |

	  equal_values = find(subject, equal_predicate, object, max, partial_match, receiver, find_equal_predicates, skip )
	  values.concat( equal_values )
	  skip -= equal_values.size
	  skip = 0 if skip < 0

	end
      end


      return values
    end

    def equal_predicates predicate 
#      return find( nil, 'http://www.w3.org/2002/07/owl#sameAs', predicate, 0, false, nil, false )
#      return find( nil, 'sub_property_of', predicate, 0, false, nil, false ).collect do | statement | statement.subject end
      return find( nil, 'http://www.w3.org/2000/01/rdf-schema#subPropertyOf', predicate, 0, false, nil, false ).collect do | statement | statement.subject end

    end


    def object subject, predicate
      statement = find( subject, predicate, nil, 1, false )[0]
      if statement.nil?
	return nil
      else
	return statement.object
      end
    end

    def objects subject, predicate
      result = Set.new
      find( subject, predicate, nil, 0, false, proc do | statement |
	     result.add( statement.object )
	     false
	   end )
      return result
    end

    def subject predicate, object
      statement = find( nil, predicate, object, 1, false )[0]
      if statement.nil?
	return nil
      else
	return statement.subject
      end
    end

    def subjects predicate, object
      result = Set.new
      find( nil , predicate, object, 0, false, proc do | statement |
	     result.add( statement.subject )
	     false
	   end )
      return result
    end


    def outgoing_predicates subjects
      result = Set.new

      subjects.each do | subject |
	find( subject, nil, nil, 0, false, proc do |statement|
	       result.add( statement.predicate )
	       false
	     end )
      end

      return result
      
    end

    def incoming_predicates objects
      
      result = Set.new

      objects.each do | object |
	find( nil, nil, object, 0, false, proc do |statement|
	       result.add( statement.predicate )
	       false
	     end )
      end

      return result

    end

    def run_query query, receiver = nil
      query.run( self, receiver )
    end

    def path_exists? source_value, path_parts, target_value, partial_match
      Path.exists?( self, source_value, path_parts, target_value, partial_match )
    end

    def path_ending source_value, path_parts
      Path.ending( self, source_value, path_parts )
    end

    def path_endings source_value, path_parts
      Path.endings( self, source_value, path_parts )
    end

    def owned_values value, result = Set.new
      find( value, nil, nil, 0, false ).each do | statement |
	if( not result.include?( statement.object ) )
	  if( subject_is_owner?( statement ) )
	    result.add( statement.object )
	    owned_values( statement.object, result )
	  end
	end
      end
    end

    def subject_is_owner? statement
      return ( object( statement.predicate, "subject_is_owner" ) == "true" or
	      object( statement.statement_id, "subject_is_owner" ) == "true" )
    end

    def domain_in_set? domains, predicate
      if( domains.nil? )
	return true 
      else
	return domains.include?( object( predicate, 'domain' ) )
      end
    end

    ## Observers

    def make_observer_key subject, predicate, object
      subject = "nil" if( not subject )
      predicate = "nil" if( not predicate )
      object = "nil" if( not object )
      return "{" + subject.to_s + "}{" + predicate.to_s + "}{" + object.to_s + "}"
    end

    def add_observer subject, predicate, object, observer

      key = make_observer_key( subject, predicate, object )
      if( ! @observers[key] )
	@observers[key] = Set.new
      end

      #      @number_of_observers += 1
      #      puts "added observer, number of observers " + @number_of_observers.to_s

      @observers[key].add( observer )

    end

    def remove_observer subject, predicate, object, observer
      key = make_observer_key( subject, predicate, object )

      if( ! @observers[key] )
	return
      end

      #      @number_of_observers -= 1
      #      puts "removed observer, number of observers " + @number_of_observers.to_s

      @observers[key].delete( observer )
      if(@observers[key].size == 0)
	@observers.delete(key)
      end
      #      puts "number of observerd statement patterns " + @observers.keys.size.to_s
    end

    def add_statement_observer statement_id, observer
      if( not @statement_observers.include?(statement_id) )
	@statement_observers[statement_id] = Set.new
      end

      #     @number_of_statement_observers += 1
      #      puts "added statement observer, number of statement observers " + @number_of_statement_observers.to_s

      @statement_observers[statement_id].add( observer )

    end

    def remove_statement_observer statement_id, observer
      if( not @statement_observers.include?(statement_id) )
	return
      end

      #      @number_of_statement_observers -= 1
      #      puts "removed statement observer, number of statement observers " + @number_of_statement_observers.to_s

      @statement_observers[statement_id].delete( observer )
      if(@statement_observers[statement_id].size == 0)
	@statement_observers.delete(statement_id)
      end
      #      puts "number of observerd statement ids " + @statement_observers.keys.size.to_s
    end

    def notify statement, change_type

      invalid_observers = Set.new

      if( [ :remove, :object_change, :subject_change ].include?( change_type ) )
	statement_observer_set = @statement_observers[statement.statement_id]
	if( statement_observer_set )
	  statement_observer_set.each do | observer |
	    begin
	      observer.update( statement, change_type )
	    rescue Exception => e
	      puts "Exception: " + e.to_s
	      puts e.backtrace.join("\n")
	      invalid_observers.add( observer )
	    end
	  end
	  invalid_observers.each do | observer |
	    puts "removing invalid observer "
	    remove_statement_observer( statement.statement_id, observer )
	  end
	end
      end

      invalid_observers.clear

      if( [ :remove, :add, :object_change, :subject_change ].include?( change_type ) )
	keys = [make_observer_key(statement.subject, statement.predicate, nil),
	  make_observer_key(statement.subject, nil, nil),
	  make_observer_key(nil, statement.predicate, statement.object),
	  make_observer_key(nil, nil, statement.object),
	  make_observer_key(statement.subject, statement.predicate, statement.object)]

	keys.each do | key |
	  observer_set = @observers[key]
	  if( observer_set )
	    observer_set.each do | observer |
	      begin
		observer.update( statement, change_type )
	      rescue Exception => e
		puts "Exception: " + e.to_s
		puts e.backtrace.join("\n")
		invalid_observers.add( observer )
	      end
	    end
	    invalid_observers.each do | observer |
	      puts "removing invalid observer " + key
	      remove_observer( statement.subject, statement.predicate, statement.object, observer )
	    end
	  end
	end
      end
    end

    # type system

    def is_of_type? value, type
      return types( value ).include?( type )
    end

    def types subject
      return [] if subject.nil?
      types = objects( subject, "http://www.w3.org/1999/02/22-rdf-syntax-ns#type" ).to_a
      types.concat( objects( subject, "type" ).to_a )
      parent_types = Set.new
      types.each do | type |
	parent_types.merge( super_types( type ) )
      end
      #      puts 'types returns ' + types.merge( parent_types ).inspect
      return types.concat( parent_types.to_a )
    end

    def sub_types type
      return Set.new if type.nil?
      subjects( 'Type_>_sub_type_of', type )
    end

    def is_sub_type_of? type, parent_type
      super_types( type ).include?( parent_type )
    end

    def super_types type
      return Set.new if type.nil?
      result = Set.new
      result = objects( type, 'Type_>_sub_type_of' )
      result.each do | super_type |
	result.merge( super_types( super_type ) )
      end
      return result
    end

    def instances type
      subjects( "type", type )
    end
    
    # functions

    def is_function? predicate
      ["enrollment_count", "accomplishment_count"].include?( predicate )
    end

    def applicable_functions subjects
      result = Set.new

      subjects.each do | subject |
	types = types( subject )

	if( types.include?( "CourseComponent" ) )
	  result.add( "enrollment_count" )
	end

	if( types.include?( "Enrollment" ) )
	  result.add( "accomplishment_count" )
	end

      end

      return result
    end

    def apply_function subject, predicate, receiver
      enough = false
      if( predicate.eql?("enrollment_count") )
	enough = receiver.call( subject, predicate, count( nil, "Enrollment_>_course_component", subject ).to_s, subject + "_" + predicate )
      end

      if( predicate.eql?("accomplishment_count") )
	enough = receiver.call( subject, predicate, count( nil, "Accomplishment_>_enrollment", subject ).to_s, subject + "_" + predicate )
      end

      return enough

    end

    # operations

    def execute_application application, gui
      type = object(application, 'type' )
      eval(object(type,'Operation_>_body')).call( self, gui, application )
    end

    private
    
    def open_database

      @last_generated_value = object( "kaivo", "last_generated_value" )
      if( @last_generated_value.nil? )
	@last_generated_value = 0
      else
	@last_generated_value = @last_generated_value.to_i
      end

    end

  end
end

