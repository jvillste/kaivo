require 'gtk2'
require 'kaivo/valuelistener'

module Kaivo
  module View
    class Value  < Gtk::HBox
      include ValueListener

      @@tip_group = Gtk::Tooltips.new

      def initialize gui, value
	super()

	@gui = gui

	initialize_value( value )

	@menu_generators = []

      end

      def handle_value_change
	set_tip()
      end

      def add_view view

	@view = view

	@view.signal_connect("button_press_event") do |widget, event|

	  result = false
	    if (event.button == 3)
	      menu = Gtk::Menu.new

	      menu.append( @gui.get_value_menu( @value ) ) if not @value.nil?


	      @menu_generators.each do | menu_generator |
		menu.append( menu_generator.call() )
	      end
	      menu.show_all
	      menu.popup( nil, nil, event.button, event.time )
	      result = true
	    elsif ( event.button == 1 and event.event_type == Gdk::Event::BUTTON2_PRESS )
	      @double_click_listener.call() if not @double_click_listener.nil?
	      result = true
	    end  

	  result
	end

	add(@view)

	set_tip()
      end

      def set_double_click_listener listener
	@double_click_listener = listener
      end

      def add_menu_generator menu_generator
	@menu_generators << menu_generator
      end

      def copy_settings other_value_view
	other_value_view.set_double_click_listener( @double_click_listener )
	@menu_generators.each do | generator |
	  other_value_view.add_menu_generator( generator )
	end
      end

      private

      def set_tip
	if( not @value or destroyed? or @view.nil?)
	  return
	end
	@@tip_group.set_tip(@view, @value, "")
      end

    end
  end
end

