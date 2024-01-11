module Kaivo
  module ValueListener

    attr_reader :value

    def initialize_value value
      @old_value = value
      @value = value
    end

    def set_value new_value
      @old_value = @value
      @value = new_value
      
      handle_value_set()
      handle_value_change()
      
    end

    def edit_value new_value
      @old_value = @value
      @value = new_value

      @edit_listener.call(@old_value, @value) if @edit_listener

      handle_value_edit()
      handle_value_change()

    end

    def set_value_edit_listener listener
      @edit_listener = listener
    end

    def handle_value_edit
    end

    def handle_value_set
    end

    def handle_value_change
    end

  end
end


