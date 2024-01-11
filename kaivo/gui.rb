require 'gtk2'
require 'kaivo/view/main'
require 'kaivo/view/table'
require 'kaivo/view/outline'
require 'kaivo/statement'
require 'kaivo/observablehash'
require 'kaivo/observablearray'
require 'set'
require 'date'

module Kaivo
  class GUI

    attr_reader :kaivo, :main_view

    def initialize kaivo
      Gtk.init


      @kaivo = kaivo

      @kaivo.add_new( "top_column", "subject_is_owner", "true" )
      @kaivo.add_new( "sub_columns", "subject_is_owner", "true" )

      @kaivo.add_new( "left_views", "subject_is_owner", "true" )
      @kaivo.add_new( "right_views", "subject_is_owner", "true" )

      @main_view = View::Main.new( self )



#      default_perspective = @kaivo.object( "gui", "default_perspective" )
#      if( not default_perspective.nil? )
#	load_perspective( default_perspective )
#      end
    end

    def GUI::container_color
      Gdk::Color.new( 50000, 50000, 65000 )
    end

    def run

      main_win = Gtk::Window.new

      main_win.add @main_view
      main_win.set_default_size( 500, 300 )
      main_win.signal_connect( "destroy" ) { Gtk.main_quit }
      main_win.show_all

      Gtk.main

    end


    def GUI::join_current_transaction kaivo
      transaction = Thread.current.instance_variable_get(:@transaction)
      if transaction.nil?
	transaction = kaivo.begin_transaction()
	Thread.current.instance_variable_set( :@transaction, transaction )
      else
	transaction.join
      end
      return transaction
    end

    def GUI::leave_current_transaction
      if( Thread.current.instance_variable_get(:@transaction).leave )
	Thread.current.instance_variable_set( :@transaction, nil )
      end
    end

    def add_history_value value
      @main_view.add_history_value value
    end

    def get_value_menu value
      GUI.create_menu_tree( "value",
			   [ get_view_menu( value ),
			     get_operations_menu( value ),
			     GUI.create_menu_item( "copy" , proc do
						    Gtk::Clipboard.get( Gdk::Selection::CLIPBOARD ).text = value
						  end ),

			     GUI.create_menu_item( "load rdf xml document", proc do
						    @kaivo.add_static_source( value, 'rdfxml' )
						  end ),

			     GUI.create_menu_item( "load kaivo document", proc do
						    @kaivo.add_static_source( value, 'kaivo' )
						  end ) ] )
      

    end

    def get_save_lens_for_type_menu values, lens
      types = Set.new
      values.each do  | value |
	types.merge(@kaivo.types( value ) )
      end
      items = types.collect do | type |
	GUI.create_menu_item( label( type ),
			     proc do
			       lens['Lens_>_suitable_types'] = type
			       lens.save( @kaivo )
			       add_default_lens_label( lens )
			       add_history_value( lens.value )
			     end )
      end
	
      GUI.create_menu_tree( "save lens for type", items )

    end

    def get_save_lens_for_value value, lens
      GUI.create_menu_item( "save lens for " + label(value),
			   proc do
			     lens['Lens_>_suitable_value'] = value
			     lens.save( @kaivo )
			     add_default_lens_label( lens )
			     add_history_value( lens.value )
			   end )

    end

    def get_view_menu value

      return GUI.create_menu_item( "Show in outline", proc do
					@main_view.add_right( View::Outline.new( self, value ) )
				      end )
    end

    def get_lens_menu value, lens
      value_types = @kaivo.types(value)
      lenses = []
      transaction = GUI::join_current_transaction( @kaivo )


      @kaivo.call_in_transaction( transaction, :subjects, 'Lens_>_suitable_value', value ).each do | view_template |
	lenses << view_template
      end

      value_types.each do | type |
	@kaivo.call_in_transaction( transaction, :subjects, 'Lens_>_suitable_types', type ).each do | view_template |
	  lenses << view_template
	end
      end


#      @kaivo.call_in_transaction( transaction, :instances, 'Lens').each do | view_template |
# 	content_types = @kaivo.call_in_transaction( transaction, :objects, view_template, "Lens_>_suitable_types" )
# 	if( content_types.size == 0 )
# 	  lenses << view_template
# 	end
#      end

      GUI::leave_current_transaction()

      items = lenses.collect do | suggested_lens |
	GUI.create_menu_item( label( suggested_lens ), proc do
			       lens.value = suggested_lens
			       lens.load( @kaivo )
			     end )
      end

      return GUI.create_menu_tree( "use lens", items )
    end

    def add_default_lens_label lens
      return if( not @kaivo.object(lens.value,'label').nil? )

      add_label( lens.value, default_lens_label( lens ) )

    end

    def default_lens_label lens
      label = ''
      if( not lens['Lens_>_suitable_value'].nil? )
	label = label( lens['Lens_>_suitable_value'] ) + ' :'
      elsif( not lens['Lens_>_suitable_types'].nil? )
	label = '(' + label( lens['Lens_>_suitable_types'] ) + ') :'
      end

      lens['lens_parts'].each do | lens_part |
	label += ' ' + label( lens_part['predicate'].to_s, { 'direction' => lens_part['direction'].to_s } )
      end

      return label
    end

    def save_perspective perspective_value

      @kaivo.remove_values_owned_by( perspective_value )
      @kaivo.remove_referrences_from( perspective_value )

      right_view_values = @main_view.right_views.collect do | view | view.to_value( @kaivo ) end
      left_view_values = @main_view.left_views.collect do | view | view.to_value( @kaivo ) end

      @kaivo.add( perspective_value, "type", "Perspective" )
      @kaivo.add( perspective_value, "left_views", ::Kaivo::Array.to_value( @kaivo, left_view_values ) )
      @kaivo.add( perspective_value, "right_views", ::Kaivo::Array.to_value( @kaivo, right_view_values ) )
    end

    def load_perspective perspective_value
      @main_view.close_all_views()

      ::Kaivo::Array.from_value( @kaivo, @kaivo.object( perspective_value, "left_views" ) ).each do | view_value |
	@main_view.add_left( View::Table.from_value( self, view_value ) )
      end

      ::Kaivo::Array.from_value( @kaivo, @kaivo.object( perspective_value, "right_views" ) ).each do | view_value |
	@main_view.add_right( View::Table.from_value( self, view_value ) )
      end

    end

    def get_operations_menu value
      items = []

      if( @kaivo.object( value, "type" ) == "Table" )
	items << GUI.create_menu_item( "show table", proc do
					@main_view.add_right( View::Table.from_value( self, value ) )
				      end )

	items << GUI.create_menu_item( "set as a view template", proc do
					@kaivo.add_new( value, "type", "ViewTemplate" )
				      end )
      end

      if( @kaivo.object( value, "type" ) == "Perspective" )
	items << GUI.create_menu_item( "show perspective", proc do
					@current_perspective_value = value
					load_perspective( value )
				      end )

	items << GUI.create_menu_item( "set as default perspective", proc do
					@kaivo.set_object( "gui", "default_perspective", value )
				      end )
      end

      if( @kaivo.is_of_type?( value, "Operation" ) )
	items << GUI.create_menu_item( "execute", proc do
					begin
					  @kaivo.execute_application( value, self )
					rescue Exception => e
					  @main_view.add_log("Error in operation:\n" + e + "\n" + e.backtrace.join("\n") )
					end
				      end )
      end

      if value.eql?("gui")
	items << GUI.create_menu_item( "save perspective", proc do
					perspective_value = @kaivo.generate_value()
					save_perspective( perspective_value )
					@main_view.add_history_value( perspective_value )
				      end )

	if( not @current_perspective_value.nil? )
	  items << GUI.create_menu_item( "save perspective over current perspective", proc do
					  perspective_value = @current_perspective_value
					  save_perspective( perspective_value )
					  @main_view.add_history_value( perspective_value )
					end )
	end
      end


      operations = Hash.new
      @kaivo.types( value ).each do | type |
	@kaivo.subjects( "range", type ).each do | predicate |
	  operation = @kaivo.object( predicate, 'domain' )
	  next if not @kaivo.is_sub_type_of?( operation, 'Operation' )
	  operations[operation] = Set.new if( not operations.has_key?( operation ) )
	  operations[operation].add( predicate )
	end
      end

      operations.each_key do | operation |
	operations[operation].each do | predicate |
	  items << GUI.create_menu_item( label( operation ) + " (" + label( predicate ) + ")",
					proc do
					  application = @kaivo.generate_value()
					  @kaivo.add( application, "type", operation )
					  @kaivo.add( application, predicate, value )
					  
					  @main_view.add_right( View::Outline.new( self, application ) )

					end )
        end
      end

      items << GUI.create_menu_item( "deep remove value", proc do
				      @kaivo.remove_value_and_owned_values(value)
				    end )

      return GUI.create_menu_tree( "operations", items )
    end

    def GUI.create_menu_tree header, menu_items
      header_item = Gtk::MenuItem.new( header )
      menu = Gtk::Menu.new
      header_item.submenu = menu

      menu_items.each do | item |
	menu.append( item )
      end

      return header_item

    end

    def GUI.create_menu_item header, procedure
      
      item = Gtk::MenuItem.new( header )
      item.signal_connect('activate') do
	procedure.call
      end

      return item
    end

    def predicate_label predicate, context
      labels = nil
      result = nil

      rdfs_label = @kaivo.object( predicate, 'http://www.w3.org/TR/1999/PR-rdf-schema-19990303#label' )

      if rdfs_label.nil?
	rdfs_label = @kaivo.object( predicate, 'http://www.w3.org/2000/01/rdf-schema#label' )
      end

      if rdfs_label.nil?
	rdfs_label = predicate
      end

      if( context["direction"] == 'subject' )
	labels = @kaivo.find( predicate, "Predicate_>_subject_label", nil ).collect do | statement | statement.object end
	result = "<- " + rdfs_label
      else
	labels = @kaivo.find( predicate, "Predicate_>_object_label", nil ).collect do | statement | statement.object end
	if( context["direction"] == 'object' )
	  result = "-> " + rdfs_label
	else
	  result = rdfs_label
	end
      end

      if( labels.size > 0 )
	label = select_label( labels, context )
	return label if not label.nil?
      end

      return result
    end

    def select_label labels, context
      labels.each do | label |
	if( context['language'].nil? or
	   @kaivo.object( label, "Label_>_language" ).eql?( context['language'] ) )
	  l = @kaivo.object( label, "Label_>_content" )
	  if not l.nil?
	    return l
	  end
	end
      end
      return nil
    end

    def label value, context = Hash.new
      generator = nil

      
      transaction =  GUI::join_current_transaction( @kaivo )

      context["language"] = @kaivo.call_in_transaction( transaction, :object, "gui", "GUI_>_language" )

      types = @kaivo.call_in_transaction( transaction, :types, value )

      types.each do | type |

	if( type == 'http://www.w3.org/1999/02/22-rdf-syntax-ns#Property' )
	  return predicate_label( value, context )
	end

	generator = @kaivo.object( type, "Type_>_label_generator" )
	break if( not generator.nil? )
      end

      if( not generator.nil? )

	GUI::leave_current_transaction()

	begin
	  label = eval(generator).call( self, value, context )
	  if( label.nil? )
	    label = ''
	  end
	  return label
	rescue Exception => e
	  @main_view.add_log("Error in label generator:\n" + e)
	  return value
	end
      else

	label = select_label( @kaivo.call_in_transaction( transaction, :objects, value, "label" ), context )

	if label.nil?
	  label = @kaivo.call_in_transaction( transaction, :object, value, 'rdf:label' )
	end

	if label.nil?
	  label = @kaivo.call_in_transaction( transaction, :object, value, 'http://www.w3.org/TR/1999/PR-rdf-schema-19990303#label' )
	end

	if label.nil?
	  label = @kaivo.call_in_transaction( transaction, :object, value, 'http://www.w3.org/2000/01/rdf-schema#label' )
	end

	if label.nil? and types.size > 0 and types[0] != value
	  label = '(' + label( types[0] )  + ')'
	end

	GUI::leave_current_transaction()

	if not label.nil?
	  return label
	else
	  return value
	end
      end
    end

    def add_label value, label, language = @kaivo.object( 'gui', 'GUI_>_language' )
      language = 'en' if language.nil?
      label_value = @kaivo.generate_value()
      @kaivo.add( label_value, 'type', 'Label' )
      @kaivo.set_object( label_value, 'Label_>_language', language )
      @kaivo.set_object( label_value, 'Label_>_content', label )
      @kaivo.add( value, 'label', label_value )

    end

    def make_suggested_properties_menu values, label, handler

      suggested_sub_properties_item = Gtk::MenuItem.new(label)
      suggested_sub_properties_menu = Gtk::Menu.new
      suggested_sub_properties_item.submenu = suggested_sub_properties_menu

      suggested_outgoing_predicates = Set.new
      suggested_incoming_predicates = Set.new

      transaction =  GUI::join_current_transaction( @kaivo )

      suggested_outgoing_predicates.merge( kaivo.call_in_transaction( transaction, :outgoing_predicates, values ) )
      suggested_outgoing_predicates.merge( kaivo.call_in_transaction( transaction, :applicable_functions, values ) )
      suggested_incoming_predicates.merge( kaivo.call_in_transaction( transaction, :incoming_predicates,  values ) )

      GUI::leave_current_transaction()

      suggested_outgoing_predicates.each do | predicate |
	item = Gtk::MenuItem.new( label( predicate, {'direction' => 'object'} ), false)
	suggested_sub_properties_menu.append( item )
	item.signal_connect('activate') do
	  handler.call( GUI::create_lens_part( { 'predicate' => predicate, 'direction' => 'object' } ) )
	end
      end

      suggested_incoming_predicates.each do | predicate |
	item = Gtk::MenuItem.new( label( predicate, {'direction' => 'subject'} ), false)
	suggested_sub_properties_menu.append( item )
	item.signal_connect('activate') do
	  handler.call( GUI::create_lens_part( { 'predicate' => predicate, 'direction' => 'subject' } )  )
	end
      end

      return suggested_sub_properties_item
    end

    def make_type_properties_menu values, label, lens_part_array
      lens_parts = Set.new
      types = Set.new

      values.each do | value |
	types.merge( @kaivo.types(value) )
      end

      types.each do | type |
	@kaivo.subjects( 'domain', type ).each do | predicate |
	  lens_parts.add( GUI::create_lens_part( { 'predicate' => predicate, 'direction' => 'object' } ) )
	end

	@kaivo.subjects( 'range', type ).each do | predicate |
	  lens_parts.add( GUI::create_lens_part( { 'predicate' => predicate, 'direction' => 'subject' } ) )
	end
      end

      items = lens_parts.collect do | lens_part |
	item = Gtk::MenuItem.new( label( lens_part['predicate'], {'direction' => lens_part['direction']} ), false)
	item.signal_connect('activate') do
	  lens_part_array << lens_part
	end
	item
      end
      
      return GUI::create_menu_tree( label, items )
    end

    def generate_property_menu value, lens_part
      property_item = Gtk::MenuItem.new("property")
      menu = Gtk::Menu.new
      property_item.submenu = menu

      if( lens_part['direction'].to_s == 'object' )
	range = @kaivo.object( lens_part['predicate'].to_s, "range" )
	if( not range.nil? )
	  types = [range] + @kaivo.sub_types( range ).to_a

	  types.each do | type |
	    item = Gtk::MenuItem.new("add new " + label( type ) )
	    menu.append( item )
	    item.signal_connect('activate') do
	      new_value = @kaivo.generate_value()
	      @kaivo.add( new_value, "type", type )
	      @kaivo.add( value, lens_part['predicate'].to_s, new_value )
	    end
	  end
	end
      else
	domain = @kaivo.object( lens_part['predicate'].to_s, "domain" )
	if( not domain.nil? )
	  types = [domain] + @kaivo.sub_types( domain ).to_a
	  types.each do | type |
	    item = Gtk::MenuItem.new("add new " + label( type ) )
	    menu.append( item )
	    item.signal_connect('activate') do
	      new_value = @kaivo.generate_value()
	      @kaivo.add( new_value, "type", type )
	      @kaivo.add( new_value, lens_part['predicate'].to_s, value )
	    end 
	  end
	end 
      end

      item = Gtk::MenuItem.new("paste")
      menu.append( item )
      item.signal_connect('activate') do
	text = Gtk::Clipboard.get( Gdk::Selection::CLIPBOARD ).wait_for_text()

	if( lens_part['direction'].to_s == 'object' )
	  @kaivo.add( value,lens_part['predicate'].to_s, text )
	else
	  @kaivo.add( text, lens_part['predicate'].to_s, value )
	end 
      end

      item = Gtk::MenuItem.new("paste duplicate")
      menu.append( item )
      item.signal_connect('activate') do
	text = Gtk::Clipboard.get( Gdk::Selection::CLIPBOARD ).wait_for_text()
	if( not text.nil? )
	  if( lens_part['direction'].to_s == 'object' )
	    @kaivo.add( value, lens_part['predicate'].to_s, @kaivo.duplicate( text ) )
	  else
	    @kaivo.add( @kaivo.duplicate( text ), lens_part['predicate'].to_s, value )
	  end
	end
      end

      item = Gtk::MenuItem.new("add new value")
      menu.append( item )
      item.signal_connect('activate') do
	if( lens_part['direction'].to_s == 'object' )
	  @kaivo.add( value, lens_part['predicate'].to_s, 'new value' )
	else
	  @kaivo.add( 'new value', lens_part['predicate'].to_s, value )
	end
      end

      item = Gtk::MenuItem.new("add unique value")
      menu.append( item )
      item.signal_connect('activate') do
	if( lens_part['direction'].to_s == 'object' )
	  @kaivo.add( value, lens_part['predicate'].to_s, @kaivo.generate_value() )
	else
	  @kaivo.add( @kaivo.generate_value(), lens_part['predicate'].to_s, value )
	end
      end

      return property_item
    end


    def generate_lens_part_menu value, lens_part
      property_item = Gtk::MenuItem.new("lens part")
      menu = Gtk::Menu.new
      property_item.submenu = menu


      valid_type = nil
      if( lens_part['direction'].to_s == 'object' )
	valid_type = @kaivo.object( lens_part['predicate'].to_s, 'range' )
      else
	valid_type = @kaivo.object( lens_part['predicate'].to_s, 'domain' )
      end
      suggested_property_items = []
      if( not valid_type.nil? )
	suggested_property_items = @kaivo.subjects( 'domain', valid_type ).collect do | suggested_property | 
	  GUI::create_menu_item( label( suggested_property ), proc do
			     lens_part['suggested_property'] = suggested_property
			   end )
	end
      end
      menu.append( GUI::create_menu_tree( 'set suggested property', suggested_property_items ) )


      item = nil
      new_direction = nil
      if( lens_part['direction'].to_s == 'object' )
	item = Gtk::MenuItem.new("change direction to subject")
	new_direction = 'subject'
      else
	item = Gtk::MenuItem.new("change direction to object")
	new_direction = 'object'
      end
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['direction'] = new_direction
      end

      item = Gtk::MenuItem.new("show values in set view")
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['value_view_container'] = 'set'
      end

      item = Gtk::MenuItem.new("show values in table view")
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['value_view_container'] = 'table'
      end

      item = Gtk::MenuItem.new("show values as icons" )
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['value_view'] = 'icon'
      end

      item = Gtk::MenuItem.new("show values as labels" )
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['value_view'] = 'label'
      end

      item = Gtk::MenuItem.new("show values as comboboxes" )
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['value_view'] = 'suggest'
      end

      item = Gtk::MenuItem.new("show values as outlines" )
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['value_view'] = 'outline'
      end

      item = Gtk::MenuItem.new("show values as images" )
      menu.append( item )
      item.signal_connect('activate') do
	lens_part['value_view'] = 'image'
      end

      return property_item
    end

    def GUI::create_lens hash = Hash.new
      ObservableHash.new( nil, { 'type' => 'Lens',
			   'lens_parts' => ObservableArray.new }.merge( hash ) )
    end

    def GUI::create_lens_part hash = Hash.new
      ObservableHash.new( nil, { 'type' => 'LensPart',
			   'predicate' => 'new property',
			   'direction' => 'object',
			   'value_view_lens' => GUI::create_lens(),
			   'value_view_container_lens' => GUI::create_lens(),
			   'value_view_container' => 'set',
			   'value_view' => 'label' }.merge( hash ) )
    end
  end
end
