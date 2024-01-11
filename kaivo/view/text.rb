require 'kaivo/view/value'

module Kaivo
  module View
    class Text < Value
      def initialize gui, value
	super( gui, value )
	
	buffer = Gtk::TextBuffer.new
	if( @value.nil? )
	  buffer.text = ''
	else
	  buffer.text = @value
	end

	buffer.signal_connect("changed") do
	  @changed = true
	end

	view = Gtk::TextView.new(buffer)

#	view.wrap_mode = Gtk::TextTag::WRAP_WORD
# 	view.signal_connect("size_request") do | me, req |
## 	  if(me.width_request < 10)
# 	    me.width_request = 50
# 	  end
#	end
# #	  width = buffer.text.length * 7
# #	  width = 400 if width > 400
# #	  width = 20 if width < 20
# #	  view.width_request = width
# 	end

	view.signal_connect("key_press_event") do |widget,event|
	  if( ( not event.state.control_mask? ) && event.keyval == Gdk::Keyval::GDK_Return )
#	    if @changed
	      @handling_edit = true
	      edit_value( view.buffer.text )
	      @handling_edit = false
	      @changed = false
#	    end
	    true
	  else
	    false
	  end
	end

	view.signal_connect("focus_out_event") do
	  if @changed
	    edit_value( view.buffer.text ) if not @handling_edit
	    @changed = false
	  end
	end

	add_view( Gtk::Frame.new.add( view ) )
      end


      def handle_value_set
	super()
	puts "value changed"
	@view.child.buffer.text = @value # if( not @handling_edit )
      end
    end
  end
end
