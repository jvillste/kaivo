require 'kaivo/valuelistener'
require 'kaivo/view/scantstatement'
require 'kaivo/view/table'
require 'kaivo/view/property'
require 'kaivo/observer'

module Kaivo
  module View
    class Outline < Gtk::VBox

      include ValueListener


      class ForeConnector < Gtk::DrawingArea

	attr_reader :last

	def initialize color
	  super()

	  modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))

	  @last = true

	  signal_connect("size_request") do | me, req |
	    me.height_request = 13
	    me.width_request = 13
	  end

	  signal_connect('expose_event') do |widget, event|
	    gc = Gdk::GC.new(window)
	    gc.rgb_fg_color = color
	    gc.set_line_attributes( 3, Gdk::GC::LINE_SOLID, Gdk::GC::CAP_ROUND, Gdk::GC::JOIN_ROUND )
	    center_width = 6
	    height = if @last
		       6
		     else
		       allocation.height
		     end

	    window.draw_line( gc, center_width, 0, center_width, height )
	    window.draw_line( gc, center_width, 6, allocation.width, 6 )

	    true
	  end

	end

	def last= last
	  @last = last
	  window.invalidate( Gdk::Rectangle.new( 0, 0, allocation.width, allocation.height ), false ) if window
	end
      end

      class AfterConnector < Gtk::VBox
	class Connector < Gtk::DrawingArea
	  def initialize color, position
	    super()

	    modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))


	    signal_connect('expose_event') do |widget, event|
	      if( destroyed? )
		puts 'exposing destroyed after connector'
	      end
	      gc = Gdk::GC.new(window)
	      gc.rgb_fg_color = color
	      gc.set_line_attributes( 3, Gdk::GC::LINE_SOLID, Gdk::GC::CAP_ROUND, Gdk::GC::JOIN_ROUND )
	      horizontal_center = allocation.width / 2

	      left_edge = 0
	      right_edge = allocation.width
	      top = 0
	      left = 0
	      bottom = 0
	      case position
	      when :single then
		left = left_edge
		right = right_edge
		top = 6
		bottom = 6
	      when :first then
		left = left_edge
		right = right_edge
		top = 6
		bottom = allocation.height
	      when :table_header then
		left = left_edge
		right = horizontal_center
		top = 6
		bottom = allocation.height
	      when :middle then
		left = horizontal_center
		right = right_edge
		top = 1
		bottom = allocation.height
	      when :last then
		left = horizontal_center
		right = right_edge
		top = 1
		bottom = 6
	      end

	      window.draw_line( gc, horizontal_center, top, horizontal_center, bottom )
	      window.draw_line( gc, left, 6, right, 6 )

	      true
	    end
	  end
	end

	def initialize color
	  super()

	  signal_connect("size_request") do | me, req |
	    me.width_request = 13
	  end

	  @header_size_group = nil
	  @color = color
	end

	def header_size_group= size_group
	  @header_size_group = size_group
	end

	def size_groups= size_groups
	  children.each do | child |
	    child.destroy()
	  end

	  if( @header_size_group )
	    connector = Connector.new( @color, :table_header )
	    @header_size_group.add_widget( connector )
	    pack_start( connector, false )
	  end
	  size_groups.each_index do | index |
	    position = nil

	    if( index == 0 )
	      if( size_groups.size > 1 )
		position = if( @header_size_group )
			     :middle
			   else
			     :first
			   end
	      else
		position = if( @header_size_group )
			     :last
			   else
			     :single
			   end
	      end
	    elsif( index > 0 and index < size_groups.size - 1 )
	      position = :middle
	    else
	      position = :last
	    end

	    connector = Connector.new( @color, position )
	    size_group = size_groups[index]
	    size_group.add_widget( connector )
	    pack_start( connector, false )
	  end

	  show_all()

	end
      end

      class Handle < Gtk::DrawingArea
	attr_reader :state

	def initialize color
	  super()
	  @state = :closed

	  width = 13
	  height = 13
	  signal_connect("size_request") do | me, req |
	    me.width_request = width
	    me.height_request = height
	  end

	  signal_connect('expose_event') do |widget, event|
	    cr = window.create_cairo_context
            cr.set_source_rgba(1.0, 1.0, 1.0)
            cr.paint

#	    cr.scale( allocation.width, allocation.height )
	    cr.set_source_rgb( color.red / 65535.0, color.green / 65535.0, color.blue / 65535.0 )


	    left = 4
	    right = width - 4
	    top = 4
	    bottom = height - 4

	    hmiddle = ( left + right )/ 2
	    vmiddle = ( top + bottom )/ 2

	    if( @state == :closed )
	      cr.move_to( left, top )
	      cr.line_to( right, vmiddle )
	      cr.line_to( left, bottom )
	      cr.line_to( left, top )
	    else
	      cr.move_to( left, top )
	      cr.line_to( right, top )
	      cr.line_to( hmiddle, bottom )
	      cr.line_to( left, top )
	    end
            cr.set_line_join(Cairo::LINE_JOIN_ROUND)
            cr.set_line_cap(Cairo::LINE_CAP_ROUND)
            cr.set_line_width(2)
	    cr.fill_preserve
	    cr.stroke
	  end

	  def state= state
	    @state = state
	    window.invalidate( Gdk::Rectangle.new( 0, 0, allocation.width, allocation.height ), false ) if window
	  end
	end
      end

      def initialize gui, value, lens = GUI::create_lens(), lens_part = nil
	super( )

	@lens = lens
	@lens_part = lens_part
	@gui = gui

	initialize_value( value )

	@handle = Handle.new(GUI::container_color)
#	@handle = Gtk::Image.new
#	@handle.stock = Gtk::Stock::ADD

	@tab_header = Gtk::Label.new( @gui.label( @value ) )

	@open = false
	@opened_once = false

	@predicate_size_group = Gtk::SizeGroup.new( Gtk::SizeGroup::HORIZONTAL )

	lens_parts_observer = Observer.new( proc do | change_type, index |
					     if( @opened_once )
					       case change_type
					       when :add then
						 add_lens_part( @lens['lens_parts'][index] )
					       when :delete then
						 delete_lens_part( index )
					       end
					     end
					   end )


	@lens['lens_parts'].add_observer( lens_parts_observer )

	signal_connect('destroy') do
	  @lens['lens_parts'].delete_observer( lens_parts_observer )
	end

	event_handle = Gtk::EventBox.new.add( @handle )
	event_handle.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	event_handle.signal_connect("button_press_event") do |widget, event|

	  result = false
	    if (event.button == 3)
	      menu = Gtk::Menu.new



	      menu.append( @gui.make_suggested_properties_menu([ @value ], "existing properties", proc do | lens_part |
								 @lens['lens_parts'] << lens_part
							       end ) )

	      menu.append( @gui.make_type_properties_menu([ @value ], "type properties", @lens['lens_parts']) )


	      menu.append( GUI.create_menu_item( "add property", proc do
						  @lens['lens_parts'] << GUI::create_lens_part()
						end ) )

	      menu.append( GUI::create_menu_tree( "set root value view", [
						   GUI.create_menu_item( 'label', proc do
									  @lens['outline_value_view'] = 'label'
									end ),
						   GUI.create_menu_item( 'icon', proc do
									  @lens['outline_value_view'] = 'icon'
									end ),
						   GUI.create_menu_item( 'image', proc do
									  @lens['outline_value_view'] = 'image'
									end ) ] ) )



	      menu.append( @gui.get_save_lens_for_type_menu( [@value], @lens ) )
	      menu.append( @gui.get_save_lens_for_value( @value, @lens ) )

	      menu.append( GUI.create_menu_item( "save lens", proc do
						  @lens.save( @gui.kaivo )
						  @gui.add_default_lens_label( @lens )
						  @gui.add_history_value( @lens.value )
						end ) )

	      menu.append( GUI.create_menu_item( "save lens as new", proc do
						  @lens['label'] = ObservableHash.new(nil, { 'type' => 'Label',
											'Label_>_language' => @gui.kaivo.object( 'gui', 'GUI_>_language' ),
											'Label_>_content' => @gui.default_lens_label(@lens) } )
						  @lens.save( @gui.kaivo, true )
						  @gui.add_history_value( @lens.value )
						end ) )

	      menu.append( @gui.get_lens_menu( @value, @lens ) )

	      menu.show_all()
	      menu.popup(nil, nil, event.button, event.time)
	      result = true
	    elsif ( event.button == 1 )
	      if(@open)
		@open = false
		@handle.state = :closed
#		@handle.stock = Gtk::Stock::ADD

		@property_box.hide()
	      else
		@open = true
		@handle.state = :open
#		@handle.stock = Gtk::Stock::REMOVE

		if( not @opened_once )
		  @lens['lens_parts'].each do | lens_part |
		    add_lens_part( lens_part )
	          end
		  @opened_once = true
		end

		@property_box.no_show_all = false
		@property_box.show_all()
		@property_box.no_show_all = true
	      end
	      result = true
	    end  
	  result
	end


	@value_view = create_outline_value_view()

	hbox = Gtk::HBox.new
	hbox.pack_start( event_handle, false )
	hbox.pack_start( @value_view, false )

	@lens.add_observer( Observer.new( proc do | property |
					   if( property == 'outline_value_view' )
					     new_value_view = create_outline_value_view()
#					     @value_view.copy_settings( new_value_view )
					     @value_view.destroy()
					     @value_view = new_value_view
					     hbox.pack_start( @value_view )
					     hbox.show_all()
					   end
					 end ) )

	pack_start( hbox, false )

	@property_box = Gtk::VBox.new
	@property_box.show_all()
	@property_box.no_show_all = true
	pack_start( @property_box, false )


      end

      def add_menu_generator generator
	@value_view.add_menu_generator( generator )
      end

      def handle_value_change
	return if destroyed?

	@value_view.set_value( @value )
	@tab_header.text = @gui.label( @value )

	@property_box.children.each do | hbox |
	  hbox.children[2].children[0].set_value( @value )
	end
      end

      def delete_all_lens_parts
	@property_box.children.each do | child |
	  destroy(child)
	end
      end

      def delete_lens_part index
	if( index == @property_box.children.size - 1 and index > 0)
	  fore_connector( -2 ).last = true
	end
	@property_box.children[ index ].destroy()
      end

      def fore_connector index
	@property_box.children[index].children[0].children[0]
      end

      def add_lens_part lens_part
	if( not @property_box.children[-1].nil? )
	  fore_connector( -1 ).last = false
	end

	hbox = Gtk::HBox.new
	predicate_box = Gtk::HBox.new
	@predicate_size_group.add_widget( predicate_box )
	hbox.pack_start( predicate_box, false )

	pacer = ForeConnector.new( GUI::container_color )
	pacer.last = true
	predicate_box.pack_start(pacer, true)

	predicate_view = Property.new( @gui, lens_part )

	predicate_box.pack_start( Gtk::Alignment.new(0,0,0,0).add( predicate_view ), false)

	predicate_view.set_value_edit_listener( proc do | old_value, new_value |
						 lens_part['predicate'] = new_value
					       end )

	value_view_container_box = Gtk::VBox.new
	value_view_container = create_value_view_container( lens_part )
	value_view_container_box.pack_start( value_view_container )

	after_connector = AfterConnector.new( GUI::container_color )
	update_after_connector( after_connector, value_view_container )
	get_value_view_container( value_view_container ).add_observer( Observer.new( proc do | change_type, index, new_value, size_group |
										      update_after_connector( after_connector, value_view_container )
										    end ) )
	
	hbox.pack_start( after_connector, false )
	hbox.pack_start( value_view_container_box , false )

	predicate_view.add_menu_generator( proc do @gui.generate_property_menu(@value, lens_part ) end )

	predicate_view.add_menu_generator( proc do @gui.generate_lens_part_menu(@value, lens_part ) end )

	predicate_view.add_menu_generator( proc do
					    item = Gtk::MenuItem.new("hide")
					    item.signal_connect('activate') do
					      @lens['lens_parts'].delete( lens_part )
					    end
					    item
					  end )


	lens_part_observer = Observer.new( proc do | change_type |
					       case change_type
					       when 'value_view_container'
						 value_view_container_box.children[0].destroy()
						 value_view_container = create_value_view_container( lens_part )
						 value_view_container_box.pack_start( value_view_container )

						 update_after_connector( after_connector, value_view_container )
						 get_value_view_container( value_view_container ).add_observer( Observer.new( proc do | change_type, index, new_value, size_group |
															       update_after_connector( after_connector, value_view_container )
												 end ) )

						 value_view_container_box.show_all()
					       end
					     end )
	lens_part.add_observer( lens_part_observer )

	hbox.signal_connect('destroy') do 
	  lens_part.delete_observer( lens_part_observer )
	end

	@property_box.pack_start( hbox )


	hbox.show_all() if @open

      end

      def get_value_view_container view_container
	if( view_container.kind_of?( Table ) )
	  return view_container.first_column_value_view_container
	else
	  return view_container
	end
      end

      def update_after_connector connector, value_view_container
	if( value_view_container.kind_of?( Table ) )
	  connector.header_size_group = value_view_container.header_size_group
	  value_view_container = value_view_container.first_column_value_view_container
	else
	  connector.header_size_group = nil
	end

	connector.size_groups = value_view_container.size_groups
      end

      def create_value_view_container lens_part
	case lens_part['value_view_container'].to_s
	when 'set' then
	  return ScantStatement.new( @gui, @value, lens_part )
	when 'table' then
	  return Table.new( @gui, @value, lens_part )
	end
      end

      def create_outline_value_view
	case @lens['outline_value_view'].to_s
	when 'icon' then
	  return Icon.new( @gui, @value )
	when 'image' then
	  return TwoPassiveState.new( @gui, @value, Image, [100], Image, [1000] )
	when 'suggest' then
	  value_view = TwoState.new( @gui, @value, Label, [{}, true], Suggest, [@lens_part] )
	  value_view.set_value_edit_listener( proc do | old_value, new_value |
						edit_value( new_value )
					      end )
	  return value_view
	else
	  value_view = TwoState.new( @gui, @value, Label, [{}, true], Text, [] )
	  value_view.set_value_edit_listener( proc do | old_value, new_value |
						edit_value( new_value )
					      end )
	  return value_view
	end
      end


      def header
	return @tab_header
      end

    end
  end
end
