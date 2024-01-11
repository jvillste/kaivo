require 'kaivo/view/value'

module Kaivo
  module View
    class Statement < Gtk::EventBox

      attr_reader :statement

      def initialize gui, statement, direction, value_view
	super()

	modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))

	box = Gtk::HBox.new()
	add(box)

	@gui = gui
	@statement = statement
	@direction = direction

	@destroyed = false
	signal_connect("destroy") do
	  @destroyed = true
	  @gui.kaivo.remove_statement_observer( @statement.statement_id, self )
	end

        @value_view = value_view
	if(@direction == 'object')
#	  @value_view = TwoState.new( @gui, @statement.object, Label, [], Text, [] )
	  @value_view.set_value( @statement.object )
	  @value_view.set_value_edit_listener( proc do | old_value, new_value |
	    @gui.kaivo.set_statement_object(@statement, new_value)
	  end )

	else
#	  @value_view = TwoState.new( @gui, @statement.subject, Label, [], Text, [] )
	  @value_view.set_value( @statement.subject )
	  @value_view.set_value_edit_listener( proc do | old_value, new_value |
	    @gui.kaivo.set_statement_subject(@statement, new_value)
	  end )
	end

	add_menu_generator(proc do
			     statement_item = Gtk::MenuItem.new("statement")
			     menu = Gtk::Menu.new
			     statement_item.submenu = menu
			     remove_item = Gtk::MenuItem.new("remove statement")
			     menu.append( remove_item )
			     remove_item.signal_connect('activate') do
			       @gui.kaivo.remove(@statement)
			     end
			     return statement_item
			   end )


	box.pack_start(@value_view, true)

	box.show_all

	@gui.kaivo.add_statement_observer( statement.statement_id, self )
      end

      def value
	if(@direction == 'object')
	  return @statement.object
	else
	  return @statement.subject
	end
      end

      def add_menu_generator menu_generator
	@value_view.add_menu_generator( menu_generator )
      end

      def update statement, change_type
	@statement = statement

	if( change_type == :object_change && @direction == 'object' )
	  @value_view.set_value( statement.object )
	elsif( change_type == :subject_change && @direction == 'subject' )
	  @value_view.set_value( statement.subject )
	else
	  destroy() if( not @destroyed )
	end
      end

      def set_mouse_enter_listener listener
	@mouse_enter_listener = listener
      end

      def set_mouse_leave_listener listener
	@mouse_leave_listener = listener
      end

      private

      def handle_mouse_enter
# 	@mouse_in_view = true
# 	@mouse_enter_listener.call() if @mouse_enter_listener
# 	Thread.new do
# 	  sleep(1)
# 	  if(not @destroyed)
# 	    @statement_view.show if @mouse_in_view
# 	  end
# 	end
      end

      def handle_mouse_leave
#         @mouse_in_view = false
# 	@mouse_leave_listener.call() if @mouse_leave_listener
# 	Thread.new do
# 	  sleep(1)
# 	  if(not @destroyed)
# 	    @statement_view.hide if( not @mouse_in_view)
# 	  end
# 	end
      end

    end
  end
end

