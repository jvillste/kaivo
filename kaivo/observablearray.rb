module Kaivo
  class ObservableArray < ::Array
    include Observable

    def []= index, value
      super( index, value )
      changed( true )
      notify_observers( :change, index )
    end

    def clear
      n = size
      super()
      n.times do
	changed(true)
	notify_observers( :delete, 0 )
      end
    end

    def delete_at index
      super( index )
      changed( true )
      notify_observers( :delete, index )
    end

    def delete item
      item_index = index( item )
      super( item )
      changed( true )
      notify_observers( :delete, item_index )
    end

    def << value
      super( value )
      changed( true )
      notify_observers( :add, size() - 1 )
    end

    def insert index, value
      super( index, value )
      changed( true )
      notify_observers( :add, index )
    end

  end
end
