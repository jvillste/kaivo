require 'kaivo/view/value'


module Kaivo
  module View
    class TwoState < Gtk::EventBox

      include ValueListener

      def initialize gui, value, passive_view_class, passive_view_parameters, modifier_class, modifier_parameters
	super()

	modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))

	@gui = gui

	initialize_value( value )

	@passive_view_class = passive_view_class
	@passive_view_parameters = passive_view_parameters
	@modifier_class = modifier_class
	@modifier_parameters = modifier_parameters

	@passive_view = @passive_view_class.new( @gui, @value, *@passive_view_parameters )

	@passive_view.set_double_click_listener( proc do
						  show_modifier()
						end )

	show_passive_view()
      end

      def handle_value_set
	@passive_view.set_value( @value )
      end

      def add_menu_generator generator
	@passive_view.add_menu_generator( generator )
      end
      
      def copy_settings other_value_view
	@passive_view.copy_settings( other_value_view )
      end

      def show_passive_view
	return if destroyed?

	@passive_view.set_value( @value )

	remove( @modifier ) if not @modifier.nil?
	add( @passive_view )
	show_all()
      end

      def show_modifier
	if @modifier.nil?
	  @modifier =  @modifier_class.new( @gui, @value, *@modifier_parameters )

	  @modifier.set_value_edit_listener( proc do | old_value, new_value |
					      edit_value( new_value )
					      show_passive_view()
					    end )

	else
	  @modifier.set_value( @value )
	end

	remove( @passive_view )
	add( @modifier )
	@modifier.grab_focus()
	show_all()

      end

    end


  end
end
