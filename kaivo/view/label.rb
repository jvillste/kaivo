require 'kaivo/view/value'

module Kaivo
  module View
    class Label < Value
      def initialize gui, value, context = {}, generate_label = true, color = "#000000"
	super( gui, value )

	@color = color
	@context = context
	@generate_label = generate_label
	@label = Gtk::Label.new
	ebox = Gtk::EventBox.new.add( Gtk::Alignment.new( 0, 0.5, 0, 0 ).add( @label ) )
	ebox.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	add_view( ebox )

	signal_connect('destroy') do
	  @gui.kaivo.remove_observer( @value, nil, nil, self )
	end

	reset_observer()
	reset_label()

      end

      def update statement, change_type
	reset_label( )
      end

      def handle_value_change
	super()

	reset_observer()
	reset_label()
      end

      def reset_observer
	@gui.kaivo.remove_observer( @old_value, nil, nil, self )
	@gui.kaivo.add_observer( @value, nil, nil, self )
      end

      def reset_label
	label = @value
	if( @generate_label )
	  label = @gui.label( @value, @context )
	end

	label = label.gsub("<",'&lt;').gsub('>','&gt;')
	@label.set_markup( '<b><span foreground="' + @color +'"> ' + label + ' </span> </b>' )
      end
    end
  end
end
