require 'kaivo/view/value'

module Kaivo
  module View
    class Suggest < Value
      def initialize gui, value, lens_part
	super( gui, value )

	valid_type = nil
	if( lens_part['direction'].to_s == 'object' )
	  valid_type = gui.kaivo.object( lens_part['predicate'].to_s, 'range' )
	else
	  valid_type = gui.kaivo.object( lens_part['predicate'].to_s, 'domain' )
	end

	@model = Gtk::ListStore.new(String, String)

	
	combo = Gtk::ComboBoxEntry.new(@model, 0)

 	if( value.nil? )
 	  value = ''
 	else
 	  if( not lens_part['suggested_property'].nil? )
 	    value = gui.kaivo.object( value, lens_part['suggested_property'] )
 	  else
	    value = gui.label( value )
 	  end
 	end

	fill_suggestions( combo, value, valid_type, lens_part )

	combo.active = 0 if( value != '' )

	combo.signal_connect("changed") do |widget,event|
	  if( combo.active_iter )
	    @handling_edit = true
	    edit_value( combo.active_iter[1] ) if( not combo.active_iter[1].nil? )
	    @handling_edit = false
	  else
	    fill_suggestions( combo, combo.active_text, valid_type, lens_part )
	  end
	end

	combo.signal_connect("key_press_event") do |widget,event|
	  puts "key press"
	  if( ( not event.state.control_mask? ) && event.keyval == Gdk::Keyval::GDK_Return )
#	    if @changed
	    @handling_edit = true
	    puts "enter press"

	    if( combo.active_iter )
	      edit_value( combo.active_iter[1] )
	    else
	      edit_value( combo.active_text )
	    end
	      @handling_edit = false
	      @changed = false
#	    end
	    true
	  elsif( event.keyval == Gdk::Keyval::GDK_Down )
	    combo.popup
	  else
	    false
	  end
	end

# 	combo.signal_connect("focus_out_event") do
# 	  if @changed
# 	    if not @handling_edit
# 	      if( combo.active_iter )
# 		edit_value( combo.active_iter[1] )
# 	      else
# 		edit_value( combo.active_text )
# 	      end
# 	    end
# 	    @changed = false
# 	  end
# 	end

	add_view( combo )
      end

      def fill_suggestions combo, active_text, valid_type, lens_part
	query = Query.new

	if( active_text != '' )
	  if( not lens_part['suggested_property'].nil? )
	    query.add_constraint( [{ :predicate => lens_part['suggested_property'],
				     :direction => :object }],
				 active_text,
				 true )
	  else
	    query.add_constraint( [{ :predicate => 'label',
				     :direction => :object },
				   { :predicate => 'Label_>_content',
				     :direction => :object }],
				 active_text,
				 true )
	  end
	end

	if( not valid_type.nil? )
	  query.add_constraint( [{ :predicate => 'type',
				   :direction => :object }],
			       valid_type,
			       false )
	end

	@model.clear
	n = 0
	@gui.kaivo.run_query( query, proc do | value |
			      iter = @model.append
			      if( not lens_part['suggested_property'].nil? )
				iter[0] = @gui.kaivo.object( value, lens_part['suggested_property'] )
			      else
				iter[0] = @gui.label( value )
			      end
			      iter[1] = value
			      n += 1
			      if( n > 15 )
				true
			      else
				false
			      end
			    end )

      end

      def handle_value_set
	super()
#	puts "value changed"
#	@view.child.buffer.text = @value # if( not @handling_edit )
      end
    end
  end
end
