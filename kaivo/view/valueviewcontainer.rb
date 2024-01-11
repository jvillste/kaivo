require 'observer'

module Kaivo
  module View
    module ValueViewContainer
      include Observable

      attr_reader :size_groups

      attr_writer :add_view_observer, :remove_view_observer, :value_change_observer

      def initialize_value_view_container
	@size_groups = ::Array.new
      end

      def notify_add_view index, view, value
	@size_groups.insert( index, Gtk::SizeGroup.new( Gtk::SizeGroup::VERTICAL ) )
	@size_groups[index].add_widget( view )
	@add_view_observer.call( index, value, @size_groups[index] ) if @add_view_observer

	changed(true)
	notify_observers( :add, index, value, @size_groups[index] )
      end

      def notify_remove_view index
	@size_groups.delete_at(index)
	@remove_view_observer.call( index ) if @remove_view_observer

	changed(true)
	notify_observers( :remove, index, nil, nil)
      end

      def notify_value_change index, new_value
	@value_change_observer.call( index, new_value ) if @value_change_observer

	changed(true)
	notify_observers( :change, index, new_value, nil )
      end

      def get_size_group index
	return @size_groups[index]
      end

    end
  end
end
