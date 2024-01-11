module Kaivo
  module View
    class Empty < Value

      def initialize gui, value
	super(gui, value)
	
	face = Gtk::DrawingArea.new

 	face.signal_connect('expose_event') do |widget, event|
 	  cr = widget.window.create_cairo_context
 	  cr.set_source_rgba(1.0, 1.0, 1.0)
 	  cr.paint

 	  cr.set_source_rgb( 0.9, 0.9, 0.9 )
 	  cr.rectangle( 2, 2, allocation.width - 4, allocation.height - 4 )
 	  cr.fill()
 	end

	face.signal_connect("size_request") do | me, req |
	  me.height_request = 13
	  me.width_request = 30
	end

	add_view( Gtk::EventBox.new.add(face) )

      end

    end
  end
end
