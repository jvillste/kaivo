require 'kaivo/view/value'

module Kaivo
  module View
    class TwoPassiveState < Value
      def initialize gui, value, view1_class, view1_parameters, view2_class, view2_parameters
	super( gui, value )
	@view1_class = view1_class
	@view1_parameters = view1_parameters
	@view2_class = view2_class
	@view2_parameters = view2_parameters

	@box = Gtk::EventBox.new

	add_view( @box )

	add_view1()
      end

      def handle_value_set
	super()
	@view1.set_value( @value ) if not @view1.nil?
	@view2.set_value( @value ) if not @view2.nil?
      end

      def add_menu_generator generator
	@view1.add_menu_generator( generator )
      end

      def add_view1
	return if destroyed?

	if @view1.nil?
	  @view1 = @view1_class.new( @gui, @value, *@view1_parameters )

	  @view1.set_double_click_listener( proc do
					     add_view2()
					   end )
	else
#	  @view1.set_value( @value )
	end

	@box.remove( @view2 ) if not @view2.nil?
	@box.add( @view1 )
	show_all()
      end

      def add_view2
	if @view2.nil?
	  @view2 =  @view2_class.new( @gui, @value, *@view2_parameters )

	  @view2.set_double_click_listener( proc do
					     add_view1()
					   end )

	else
#	  @view2.set_value( @value )
	end

	@box.remove( @view1 )
	@box.add( @view2 )
	show_all()

      end

    end


  end
end
