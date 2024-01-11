require 'kaivo/view/value'

module Kaivo
  module View
    class Icon < Value

      class Bullet < Gtk::DrawingArea

	def initialize
	  super()

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
	    cr.scale( allocation.width, allocation.height )
            cr.set_source_rgb( 0,0,0 )

	    cr.arc(0.5, 0.5, 0.25, 0.0, 2*Math::PI)
	    cr.fill

	  end
	end
      end

      def initialize gui, value
	super( gui, value )
	ebox = Gtk::EventBox.new.add( Gtk::HBox.new.pack_start( Bullet.new(), false ) )
      	ebox.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	add_view( ebox )
      end

    end
  end
end
