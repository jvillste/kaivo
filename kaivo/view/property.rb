module Kaivo
  module View
    class Property < Gtk::VBox

      def initialize gui, lens_part
	super()

	@gui = gui
	@lens_part = lens_part
	@lens_part.add_observer( Observer.new( proc do | change_type |
						case change_type
						when 'predicate' then
						  refresh()
						when 'direction' then
						  refresh()
						end
					      end ) )

	@menu_generators = []
	@value_edit_listener = nil
	refresh()
      end

      def set_value_edit_listener listener
	@value_edit_listener = listener
	@view.set_value_edit_listener( listener )
      end

      def add_menu_generator menu_generator
	@menu_generators << menu_generator
	@view.add_menu_generator( menu_generator ) if not @view.nil?
      end

      def refresh
	@view.destroy() if not @view.nil?
	@view = TwoState.new( @gui, @lens_part['predicate'].to_s, Label, [{"direction" => @lens_part['direction'].to_s }, true, '#3030ff'], Text, [] )
	pack_start(@view, true )
	@view.set_value_edit_listener( @value_edit_listener )
	
	@menu_generators.each do | menu_generator |
	  @view.add_menu_generator( menu_generator )
	end
      end

    end
  end
end
