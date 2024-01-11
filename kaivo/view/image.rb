require 'open-uri'
require 'kaivo/view/value'

module Kaivo
  module View
    class Image < Value
      def initialize gui, value, max_height = 100
	super( gui, value )

	@max_height = max_height
	@image = Gtk::Image.new

	set_value( value )

	ebox = Gtk::EventBox.new.add(Gtk::Alignment.new(0,0.5,0,0).add( @image ))
	ebox.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	add_view( ebox )

      end

      def handle_value_change
	super

	begin

#	  pix = Gdk::Pixbuf.new(@gui.kaivo.object(@value, 'file_name'))

	  pix = nil
	  open(@value) do |f|
	    loader = Gdk::PixbufLoader.new
	    loader.last_write(f.read)
	    pix = loader.pixbuf
	  end
	  
	  if(pix.height > @max_height)
	    pix = pix.scale(@max_height * (pix.width.to_f / pix.height.to_f),@max_height)
	  end
	  @image.pixbuf = pix

	rescue Exception => e
	  @image.stock = Gtk::Stock::MISSING_IMAGE
	end

      end
    end
  end
end
