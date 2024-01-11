require 'kaivo/view/valueviewcontainer'
require 'kaivo/view/empty'
require 'kaivo/view/table'

module Kaivo
  module View
    class ScantStatement < Gtk::EventBox

      include ValueViewContainer

      attr_reader :value

      def initialize gui, value, lens_part
	super()

	modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))

	initialize_value_view_container()

	@gui = gui
	@value = value
	@lens_part = lens_part
	@predicate = lens_part['predicate']
	@direction = lens_part['direction']


	@filters = []
	@sortings = []
	@skip = 0
	@max = 15

	lens_part_observer = Observer.new( proc do | change_type |
				  case change_type
				  when 'predicate' then

				    @gui.kaivo.remove_observer( subject(), @predicate, object(), self )
				    @predicate = @lens_part['predicate'].to_s
				    @gui.kaivo.add_observer( subject(), @predicate, object(), self )

				    refresh()
  
				  when 'direction' then

				    @gui.kaivo.remove_observer( subject(), @predicate, object(), self )
				    @direction = @lens_part['direction'].to_s
				    @gui.kaivo.add_observer( subject(), @predicate, object(), self )

				    refresh()

				  when 'value_view' then
				    @statement_box.children.each do | boxed_statement_view |
						view = boxed_statement_view.children[0]
						if( @statements.size > 0 )
						  boxed_statement_view.pack_start( create_statement_view( view.statement ), false )
						  boxed_statement_view.remove(view)
						end
					      end
				    @statement_box.show_all()
				  end
				end )

	@lens_part.add_observer( lens_part_observer )

	@statement_box = Gtk::VBox.new

 	@more = Gtk::EventBox.new.add(Gtk::Label.new('>'))
	@more.show_all()
	@more.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	@more.no_show_all = true
	@more.hide()
	@more.signal_connect("button_press_event") do |widget, event|
	  if ( event.button == 1 )
	    increase_skip
	    true
	  else
	    false
	  end  
	end

 	@less = Gtk::EventBox.new.add(Gtk::Label.new('<'))
	@less.show_all()
	@less.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	@less.no_show_all = true
	@less.hide()
	@less.signal_connect("button_press_event") do |widget, event|
	  if ( event.button == 1 )
	    decrease_skip
	    true
	  else
	    false
	  end  
	end

	add( Gtk::VBox.new.pack_start(@statement_box, false).pack_start(Gtk::HBox.new.pack_start(@less, false ).pack_start(@more, false ) ) )

	@statements = Set.new
	@statement_observers = Hash.new

# 	signal_connect("button_press_event") do |widget, event|
# 	  if not @value.nil?
# 	    if (event.button == 3)
# 	      menu = Gtk::Menu.new
# 	      menu.append( @gui.generate_property_menu( @value, @lens_part ) )
# 	      menu.show_all
# 	      menu.popup(nil,nil,event.button,event.time)
# 	      true
# 	    elsif ( event.button == 1 and event.event_type == Gdk::Event::BUTTON2_PRESS )
# 	      if( @direction == 'object' )
# 		@gui.kaivo.add( @value, @predicate, "new value" )
# 	      else
# 		@gui.kaivo.add( "new value", @predicate, @value )
# 	      end
# 	    end
# 	  end
# 	end

	signal_connect("destroy") do
	  @lens_part.delete_observer( lens_part_observer )

	  @gui.kaivo.remove_observer( subject(), @predicate, object(), self )

	  @statement_observers.each_key do | statement_id |
	    @gui.kaivo.remove_statement_observer( statement_id, @statement_observers[statement_id] )
	  end

#	  clear_statement_views
	end

	if( @value.nil? )
	  add_empty_cell()
	else
	  set_value( @value )
	end

      end

      def view_count
	return @statement_box.children.size
      end

      def viewed_values
	result = []

	@statement_box.children.each do | boxed_statement_view |
	  statement_view = boxed_statement_view.children[0]
	  result << statement_view.value if statement_view.kind_of?( Statement )
	end

	return result
      end

      def clear_statement_views
	@statement_box.children.size.times do
	  notify_remove_view( 0 )
	end

	@statement_box.children.each do | child |
	  child.destroy()
	end
      end

      def add_empty_cell
	clear_statement_views()

	cell = nil
	case @lens_part['value_view'].to_s
	when 'suggest'
	  cell = TwoState.new( @gui, nil, Empty, [], Suggest, [@lens_part] )
	else
	  cell = TwoState.new( @gui, nil, Empty, [], Text, [] )
	end

	cell.set_value_edit_listener( proc do | old_value, new_value |
				       if( @lens_part['direction'].to_s == 'object' )
					 @gui.kaivo.add(@value, @lens_part['predicate'].to_s, new_value)
				       else
					 @gui.kaivo.add(new_value, @lens_part['predicate'].to_s, @value)
				       end
				     end )

	cell.add_menu_generator( proc do
				  @gui.generate_property_menu( @value, @lens_part )
				end )


	@statement_box.pack_start( Gtk::HBox.new.pack_start(cell) , true)
	notify_add_view( 0, cell, nil )
	@statement_box.show_all()
      end


#       def statement_views
# 	if(@statement_box.children[0].instance_of?(Gtk::EventBox))
# 	  return []
# 	else
# 	  return @statement_box.children
# 	end
#       end

      def subject
	if( @direction == 'object' )
	  return @value
	else
	  return nil
	end
      end

      def object
	if( @direction == 'object' )
	  return nil
	else
	  return @value
	end
      end

      def filters= filters
	@filters = filters
	refresh()
      end

      def sortings= sortings
	@sortings = sortings
	refresh()
      end

      def refresh
	clear_statement_views()

	@statements.clear()

	transaction = GUI::join_current_transaction( @gui.kaivo )

	if( not @value.nil? )

	  if( @filters.size > 0 or @sortings.size > 0)
	    query = Query.new

	    @filters.each do | filter |
	      query.add_constraint( filter[:path], filter[:value] )
	    end

	    @sortings.each do | sorting |
	      query.add_sorting( sorting[:path], sorting[:value] )
	    end

	    query.add_constraint( [{ :predicate => @lens_part['predicate'].to_s,
				     :direction => (  @lens_part['direction'].to_s.eql?( 'subject' ) ? :object : :subject )}],
				 @value,
				 false )
	    query.skip = @skip

	    n = 0
	    @gui.kaivo.call_in_transaction( transaction, :run_query, query, proc do | value |
					     if( @lens_part['direction'].to_s.eql?( 'subject' ) )
					       @gui.kaivo.call_in_transaction( transaction, :find, value, @lens_part['predicate'].to_s, @value, 0, false, proc do | statement |
										add_statement_view( statement )
										n += 1
										false
									      end )
					     else
					       @gui.kaivo.call_in_transaction( transaction, :find, @value, @lens_part['predicate'].to_s, value, 0, false, proc do | statement |
										add_statement_view( statement )
										n += 1
										false
									      end )

					     end

					     if( n == @max )
					       true
					     else
					       false
					     end
					   end )

	  else

	    @gui.kaivo.call_in_transaction( transaction, :find, subject(), @lens_part['predicate'].to_s, object(), @max, false, nil, true, @skip).each do | statement |
	      add_statement_view(statement)
	    end

	  end
	end

	GUI::leave_current_transaction()

	if(@statement_box.children.size == 0)
	  add_empty_cell( )
	end

	@statement_box.show_all()

	if( @statement_box.children.size == @max )
	  @more.show()
	else
	  @more.hide()
	end

	if( @skip > 0 )
	  @less.show()
	else
	  @less.hide()
	end
	
      end

      def decrease_skip
	@skip -= @max
	@skip = 0 if @skip < 0
	refresh()
      end

      def increase_skip
	@skip += @max
	refresh()
      end

      def set_value value
	return if( value.nil? )

	@gui.kaivo.remove_observer( subject(), @predicate, object(), self )
	@value = value
	@gui.kaivo.add_observer( subject(), @predicate, object(), self )

	refresh()

      end

      def create_statement_view statement

	value_view = nil
	case @lens_part['value_view'].to_s
	when 'label' then
	  value_view = TwoState.new( @gui, '', Label, [{}, true], Text, [] )
	when 'suggest' then
	  value_view = TwoState.new( @gui, '', Label, [{}, true], Suggest, [@lens_part] )
	when 'outline' then
	  value_view = Outline.new( @gui, '', @lens_part['value_view_lens'], @lens_part )
	when 'icon' then
	  value_view = Icon.new( @gui, '' )
	when 'image' then
	  value_view = TwoPassiveState.new( @gui, '', Image, [100], Image, [1000] )
	end

	statement_view = Statement.new( @gui, statement, @direction, value_view )
	statement_view.add_menu_generator( proc do
					    @gui.generate_property_menu( @value, @lens_part )
					  end )
	return statement_view

      end

      def add_statement_view statement
	if( @statements.include?( statement.statement_id ) )
	  return
	end

	if( @statement_box.children.size > 0 and @statements.size == 0 )
	  @statement_box.children[0].destroy
	  notify_remove_view( 0 )
	end

	statement_view = create_statement_view( statement )

	boxed_statement_view = Gtk::VBox.new
	boxed_statement_view.pack_start( statement_view, false)
	@statement_box.pack_start( boxed_statement_view , false )
#	@statement_box.reorder_child( boxed_statement_view , 0)

	notify_add_view( @statement_box.children.size - 1, boxed_statement_view, statement_view.value )

	@statements.add( statement.statement_id )

	observer = Observer.new
	observer.set_procedure( proc do | statement, change_type |
				 if(destroyed?)
				   statement.delete_observer( observer )
				   return
				 end

				 if( ( change_type == :object_change && @direction == 'subject' ) ||
				    ( change_type == :subject_change && @direction == 'object' ) ||
				    ( change_type == :remove ) )

				   @gui.kaivo.remove_statement_observer( statement.statement_id, observer )
				   @statements.delete( statement.statement_id )

				   i = @statement_box.children.index(boxed_statement_view)
				   notify_remove_view( i ) if not i.nil?

				   boxed_statement_view.destroy if not boxed_statement_view.destroyed?

				   if(@statement_box.children.size == 0)
				     add_empty_cell()
				   end

				 else
				   notify_value_change( @statement_box.children.index( boxed_statement_view ), statement_view.value )
				 end
			       end )


	@gui.kaivo.add_statement_observer( statement.statement_id, observer )
	@statement_observers[statement.statement_id] = observer

	signal_connect("destroy") do
	  @gui.kaivo.remove_statement_observer( statement.statement_id, observer )
	end

      end
      
      def update statement, change_type
	add_statement_view( statement ) if not change_type == :remove
	show_all()
      end

    end
  end
end

