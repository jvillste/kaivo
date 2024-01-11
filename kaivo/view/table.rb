require 'gtk2'
require 'kaivo/observer'
require 'kaivo/array'
require 'kaivo/view/statement'
require 'kaivo/view/text'
require 'kaivo/view/icon'
require 'kaivo/view/label'
require 'kaivo/view/twostate'
require 'kaivo/view/twopassivestate'
require 'kaivo/view/image'
require 'kaivo/view/outline'
require 'kaivo/query'

require 'kaivo/gui'

require 'kaivo/path'
require 'kaivo/filter'

require 'set'


module Kaivo
  module View
    class Table < Gtk::VBox

      class HGridLine < Gtk::EventBox
	def initialize
	  super()
	  set_height_request(2)
	  modify_bg(Gtk::STATE_NORMAL, @@color)
	end
	def HGridLine::color= color
	  @@color = color
	end
      end

      class VGridLine < Gtk::EventBox
	def initialize
	  super()
	  set_width_request(4)
	  modify_bg(Gtk::STATE_NORMAL, @@color )
	end
	def VGridLine::color= color
	  @@color = color
	end
      end

      class Column < Gtk::HBox
	attr_reader :sub_columns, :filter_value, :sorting, :lens_part
	
	attr_accessor :parent, :header_box, :iconized

	def initialize gui, lens_part, parent = nil
	  super()

	  @size_group = Gtk::SizeGroup.new( Gtk::SizeGroup::HORIZONTAL )


	  @scant_statement_box = Gtk::VBox.new
	  @size_group.add_widget(@scant_statement_box )

	  pack_start( @scant_statement_box, false )
	  pack_start(VGridLine.new, false)

	  @gui = gui
	  @lens_part = lens_part
	  @predicate = lens_part['predicate'].to_s
	  @direction = lens_part['direction'].to_s
	  @filter_value = ""
	  @sorting = :none
	  @sub_columns = []
	  @parent = parent

	  @lens_part.add_observer( Observer.new( proc do | change_type |
				    case change_type
				    when 'predicate' then

				      @predicate = @lens_part['predicate'].to_s
				      
				    when 'direction' then

				      @direction = @lens_part['direction'].to_s

				    end
				  end ) )

	lens_parts_observer = Observer.new( proc do | change_type, index |
							 case change_type
							 when :add then
							   add_sub_column( Column.new(@gui, @lens_part['value_view_container_lens']['lens_parts'][index] ) )
							 when :delete then
							   remove_sub_column( @sub_columns[ index ] )
							 end
						       end )

	 @lens_part['value_view_container_lens']['lens_parts'].add_observer( lens_parts_observer )

	signal_connect('destroy') do 
	  @lens_part['value_view_container_lens']['lens_parts'].delete_observer( lens_parts_observer )
	end


	  @lens_part['value_view_container_lens']['lens_parts'].each do | sub_column_lens_part |
	    add_sub_column( Column.new( @gui, sub_column_lens_part ) )
	  end
	end

	def first_value_view_container
	  @scant_statement_box.children[0]
	end

	def add_scant_statement_view index, new_scant_statement_view
	  @scant_statement_box.pack_start( new_scant_statement_view, false )
	  @scant_statement_box.reorder_child( new_scant_statement_view, index )
#	  grid_line = HGridLine.new
#	  @scant_statement_box.pack_start( grid_line, false )
#	  @scant_statement_box.reorder_child( grid_line, index + 1 )


	  sub_index = count_sub_index( index )

	  new_scant_statement_view.add_view_observer = proc do | index, new_value, size_group |
	    @sub_columns.each do | sub_column |
	      new_view = ScantStatement.new( @gui, new_value, sub_column.lens_part )
	      size_group.add_widget( new_view )
	      sub_column.add_scant_statement_view( index + sub_index, new_view )
	    end
	  end

	  new_scant_statement_view.remove_view_observer = proc do | index |
	    @sub_columns.each do | sub_column |
	      sub_column.remove_value( index + sub_index )
	    end
	  end

	  new_scant_statement_view.value_change_observer = proc do | index, new_value |
	    @sub_columns.each do | sub_column |
	      sub_column.change_value( index + sub_index, new_value )
	    end
	  end

	  new_values = new_scant_statement_view.viewed_values
	  new_values << nil if( new_values.size == 0 )
	  @sub_columns.each do | sub_column |
	    new_values.each_index do | i |
	      sub_column_scant_statement_view = ScantStatement.new( @gui, new_values[i], sub_column.lens_part )
	      new_scant_statement_view.get_size_group(i).add_widget( sub_column_scant_statement_view )
	      sub_column.add_scant_statement_view( i + sub_index, sub_column_scant_statement_view )
	    end
	  end

	  show_all()

	end

	def count_sub_index index
	  sub_index = 0
	  @scant_statement_box.children.each_index do | i |
	    if( i < index )
	      sub_index += @scant_statement_box.children[i].view_count()
	    end
	  end
	  return sub_index
	end

	def sub_column_lens_parts
	  @lens_part['value_view_container_lens']['lens_parts']
	end

	def add_value index, new_value
	  add_scant_statement_view( index, ScantStatement.new( @gui, new_value, @lens_part ) )
	end

	def remove_all_values
	  @scant_statement_box.children.size.times do
	    remove_value( 0 )
	  end
	end

	def remove_value index
	  sub_index = count_sub_index( index )
	  @sub_columns.each do | sub_column |
	    sub_column.remove_value( sub_index )
	  end
	  @scant_statement_box.children[index].destroy() if not @scant_statement_box.children[index].nil?
	end

	def change_value index, new_value
	  @scant_statement_box.children[index].set_value( new_value )
	end

	def add_widget_to_size_group( widget )
	  @size_group.add_widget( widget )
	end

	def predicate
	  @lens_part['predicate'].to_s
	end

	def predicate= new_predicate
	  @lens_part['predicate'] = new_predicate
	end

	def direction
	  @lens_part['direction'].to_s.to_sym
	end

	def direction= new_direction
	  @lens_part['direction'] = new_direction
	end


	def move_right moved_sub_column
	  index = @sub_columns.index( moved_sub_column )
	  
	  return if( index == @sub_columns.size - 1 )

	  @sub_columns.delete_at(index)
	  @sub_columns.insert(index + 1, moved_sub_column)

	  update_with_header()
	end

	def move_left moved_sub_column
	  index = @sub_columns.index( moved_sub_column )

	  return if( index == 0 )

	  @sub_columns.delete_at(index)
	  @sub_columns.insert(index - 1, moved_sub_column)

	  update_with_header()
	end

	def raise raised_sub_column
	  return if( @parent.nil? )
	  @sub_columns.delete( raised_sub_column )
	  @parent.add_right( self, raised_sub_column )

	  update_with_header()
	end

	def lower lowered_sub_column
	  index = @sub_columns.index( lowered_sub_column )
	  return if( index == 0 )

	  @sub_columns.delete( lowered_sub_column )
	  @sub_columns[index - 1].add_sub_column( lowered_sub_column )

	  update_with_header()
	end

	def add_right sibling_sub_column, added_sub_column
	  index = @sub_columns.index( sibling_sub_column )
	  @sub_columns.insert( index + 1, added_sub_column )

	  added_sub_column.parent = self

	  update_with_header()
	end


	def add_sub_column sub_column
	  @sub_columns << sub_column
	  sub_column.parent = self
	  pack_start( sub_column, false )

	  index = 0
	  @scant_statement_box.children.each do | scant_statement_view |

	    values = scant_statement_view.viewed_values
	    values << nil if( values.size == 0 )

	    values.each_index do | box_index |

	      sub_column_scant_statement_view = ScantStatement.new( @gui, values[box_index], sub_column.lens_part )
	      scant_statement_view.get_size_group(box_index).add_widget( sub_column_scant_statement_view )
	      sub_column.add_scant_statement_view( index + box_index, sub_column_scant_statement_view )

	    end

	    index += values.size
	  end

	  show_all()
	  update_header()
	end

	def remove_sub_column sub_column
	  sub_column.destroy()
	  @sub_columns.delete( sub_column )

	  update_header()
	end

	def sub_column_index sub_column
	  @sub_columns.index( sub_column )
	end

	def remove_all_sub_columns
	  @sub_columns.clear

	  update_with_header()
	end


	def is_first_column? sub_column
	  return ( @parent.nil? and @sub_columns.index( sub_column ) == 0 )
	end

	def set_header header
	  @header = header
	end

	def set_filter filter
	  @filter = filter
	end

	def filter_value= filter_value
	  @filter_value = filter_value
	  tc = top_column()
	  tc.first_value_view_container.filters = tc.get_filters()
#	  update_all()
	end

	def sorting= sorting
	  clear_sorting()
	  @sorting = sorting
	  tc = top_column()
	  tc.first_value_view_container.sortings = tc.get_sortings()
	  update_header()
	end

	def clear_sorting
	  top_column.set_variables( :@sorting, :none )
	end

	def update_all
	  top_column.update()
	end

	def update_all_with_header
	  top_column.update_with_header()
	end

	def top_column
	  if( not @parent.nil? )
	    return @parent.top_column()
	  else
	    return self
	  end
	end

	def update
	  update_header()
	  all_values = values()
	  remove_all_values()
	  all_values.each_index do | index |
	    add_value( index, all_values[index] )
	  end
	end

	def update_header
	  @header.refresh() if( @header )
	  @filter.refresh() if( @filter )
	  @header_box.refresh() if @header_box
	end

	def update_with_header
#	  @header.refresh() if( @header )
#	  @filter.refresh() if( @filter )
	  update()
	end

	def set_variables variable, value
	  instance_variable_set( variable, value )

	  @sub_columns.each do | sub_column |
	    sub_column.set_variables( variable, value )
	  end

	end

	def get_variables variable, ignored_value, path = []
	  values = []
	  if( not instance_variable_get( variable ).eql?( ignored_value ) )
	    values << { :path => path, :value => instance_variable_get( variable ) }
	  end

	  @sub_columns.each do | sub_column |
	    sub_path = path.clone
	    sub_path  << { :predicate => sub_column.predicate, :direction => sub_column.direction }
	    values = values + sub_column.get_variables( variable, ignored_value, sub_path )
	  end

	  return values

	end

	def get_filters
	  get_variables( :@filter_value, "" )
	end

	def get_sortings
	  get_variables( :@sorting, :none )
	end

	def viewed_values_with_nils
	  values = []

	  @scant_statement_box.children.each do | scant_statement_view |
	    scant_statement_view_values = scant_statement_view.viewed_values
	    if ( scant_statement_view_values.size == 0 )
	      values << nil
	    else
	      values += scant_statement_view_values
	    end
	  end

	  return values
	end

	def viewed_values
	  values = []

	  @scant_statement_box.children.each do | scant_statement_view |
	    values += scant_statement_view.viewed_values
	  end

	  return values
	end

	def values
	  values = []

	  @scant_statement_box.children.each do | scant_statement_view |
	    values << scant_statement_view.value
	  end

	  return values

	end

      end

      class ColumnHeader < Gtk::VBox
	def initialize gui, column
	  super( )

	  @gui = gui
	  @column = column
	  @column.set_header( self )

	  refresh()
	end

	def refresh
	  children.each do | child |
	    child.destroy
	  end

	  predicate_view = TwoState.new( @gui, @column.predicate, Label, [{"direction" => @column.direction}, true, '#4040ff'], Text, [] )
	  header_view = predicate_view
	  if( @column.sorting == :ascending )
	    header_view = Gtk::HBox.new.pack_start( predicate_view, false).pack_start( Gtk::Alignment.new(0,0.5,0,0).add(Gtk::Label.new("<")), true )
	  elsif( @column.sorting == :descending )
	    header_view = Gtk::HBox.new.pack_start( predicate_view, false).pack_start( Gtk::Alignment.new(0,0.5,0,0).add(Gtk::Label.new(">")), true )
	  end

	  pack_start( header_view, false )
	  @column.add_widget_to_size_group( header_view ) if( @column.sub_columns.size == 0 )

	  pack_start( HGridLine.new, false )
	  
	  predicate_view.set_value_edit_listener( proc do | old_value, new_value |
						      @column.predicate = new_value
						    end )

	  predicate_view.add_menu_generator( proc do @gui.generate_lens_part_menu(@value, @column.lens_part ) end )

	  predicate_view.add_menu_generator(proc do
					      main_item = Gtk::MenuItem.new("header")
					      menu = Gtk::Menu.new
					      main_item.submenu = menu

					      menu.append( @gui.make_suggested_properties_menu( @column.viewed_values(), "existing sub properties", proc do | lens_part|
												 @column.lens_part['value_view_container_lens']['lens_parts'] << lens_part
											    end ) )

					      menu.append( @gui.make_type_properties_menu( @column.viewed_values(), "sub type properties", @column.lens_part['value_view_container_lens']['lens_parts'] ) )

					      item = Gtk::MenuItem.new("paste")
					      menu.append( item )
					      item.signal_connect('activate') do
						text = Gtk::Clipboard.get( Gdk::Selection::CLIPBOARD ).wait_for_text()
						if( not text.nil? )
						  predicate_view.set_value( text )
						  @column.predicate = text
						end
					      end



					      if( @column.sorting == :none or @column.sorting == :descending )
						item = Gtk::MenuItem.new("sort ascending")
						menu.append( item )
						item.signal_connect('activate') do
						  @column.sorting = :ascending
						end
					      else
						item = Gtk::MenuItem.new("sort descending")
						menu.append( item )
						item.signal_connect('activate') do
						  @column.sorting = :descending
						end
					      end


					      item = nil
					      new_direction = nil
					      if( @column.direction == :object )
						item = Gtk::MenuItem.new("change direction to subject")
						new_direction = :subject
					      else
						item = Gtk::MenuItem.new("change direction to object")
						new_direction = :object
					      end
					      menu.append( item )
					      item.signal_connect('activate') do
						@column.direction = new_direction
					      end

					      item = Gtk::MenuItem.new("add sub column")
					      menu.append( item )
					      item.signal_connect('activate') do
						@column.parent.sub_column_lens_parts << GUI::create_lens_part()
					      end

					      item = Gtk::MenuItem.new("add column right")
					      menu.append( item )
					      item.signal_connect('activate') do
						index = @column.parent.sub_column_lens_parts.index( @column.lens_part )
						@column.parent.sub_column_lens_parts.insert( index, GUI::create_lens_part() )
					      end

# 					      item = Gtk::MenuItem.new("move column down")
# 					      menu.append( item )
# 					      item.signal_connect('activate') do
# 						@column.parent.lower( @column )
# 					      end

# 					      item = Gtk::MenuItem.new("move column up")
# 					      menu.append( item )
# 					      item.signal_connect('activate') do
# 						@column.parent.raise( @column )
# 					      end

					      item = Gtk::MenuItem.new("move column left")
					      menu.append( item )
					      item.signal_connect('activate') do
						@column.parent.move_left( @column )
					      end

					      item = Gtk::MenuItem.new("move column right")
					      menu.append( item )
					      item.signal_connect('activate') do
						@column.parent.move_right( @column )
					      end

					      item = Gtk::MenuItem.new("hide column")
					      menu.append( item )
					      item.signal_connect('activate') do
						@column.parent.lens_part['value_view_container_lens']['lens_parts'].delete( @column.lens_part )
					      end

					      return main_item
					    end )

	  sub_header_box = Gtk::HBox.new( )
	  pack_start( sub_header_box, true )

	  spacer = Gtk::EventBox.new
	  spacer.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	  @column.add_widget_to_size_group( spacer )
	  sub_header_box.pack_start( spacer, false )
#	  spacer.signal_connect("size_request") do | me, req |
#	    if(@column.sub_columns.size == 0)
#	      spacer.width_request = header_view.size_request[0]
#	      spacer.height_request = 0
#	    else
#	      spacer.width_request = 20
#	    end
#	  end

	  @column.sub_columns.each do | sub_column |
	    sub_header_box.pack_start( VGridLine.new, false )
	    sub_header_box.pack_start( ColumnHeader.new( @gui, sub_column ), false )
	  end

	  show_all()

	end
      end

      class HeaderBox < Gtk::HBox
	def initialize gui, top_column
	  super()

	  @gui = gui
	  @top_column = top_column
	  @top_column.header_box = self

	  refresh()
	end

	def refresh

	  children.each do | child |
	    child.destroy
	  end


	  @top_column.sub_columns.each do | sub_column |
	    pack_start( VGridLine.new, false ) if( children.size > 0 )
	    pack_start( ColumnHeader.new( @gui, sub_column), false )
	  end

	  show_all()

	end

      end

      class FilterBox < Gtk::HBox
	def initialize gui, top_column
	  super()

	  @gui = gui
	  @top_column = top_column
	  @top_column.set_filter( self )
	  
	  refresh()
	end

	def refresh

	  children.each do | child |
	    child.destroy
	  end

	  @top_column.sub_columns.each do | sub_column |
	    pack_start( VGridLine.new, false ) if( children.size > 0 )
	    pack_start( ColumnFilter.new( @gui, sub_column ), false )
	  end

	  show_all()

	end

      end

      class ColumnFilter < Gtk::HBox
	def initialize gui, column
	  super( )

	  @gui = gui
	  @column = column
	  @column.set_filter( self )

	  refresh()
	end

	def refresh
	  children.each do | child |
	    child.destroy
	  end

	  filter_view = Text.new( @gui, @column.filter_value )

	  pack_start( filter_view, false )
	  
	  filter_view.set_value_edit_listener( proc do | old_value, new_value |
						      @column.filter_value = new_value
						    end )
	  @column.add_widget_to_size_group( filter_view )

	  @column.sub_columns.each do | sub_column |
	    pack_start( VGridLine.new, false )
	    pack_start( ColumnFilter.new( @gui, sub_column ), false )
	  end

	  show_all()

	end
      end


      def initialize gui, value, lens_part

	super()

	HGridLine::color = GUI::container_color
	VGridLine::color = Gdk::Color.new(65535,65535,65535)

	modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))

	@value = value
	@gui = gui
	@lens_part = lens_part

	@top_column = Column.new( @gui, lens_part )
	@top_column.add_value( 0, value )

	header_row = Gtk::HBox.new


#	pack_start(HGridLine.new, false)

#	left_upper_box.height_request = 30



#Gtk::HBox.new.pack_start(Gtk::VBox.new.pack_start(, false), true)
	left_upper_box = Gtk::EventBox.new
	left_upper_box.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))

#	left_upper_box_content = Gtk::VBox.new
#	left_upper_box_content.pack_start(Gtk::Label.new("table"))
#	left_upper_box_content.pack_start(HGridLine.new, false)

#	left_upper_box.add( Gtk::Alignment.new(0,1,1,0).add(HGridLine.new ) )
#	left_upper_box.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(50000,50000,50000))
	@top_column.add_widget_to_size_group( left_upper_box )
	left_upper_box.signal_connect("size_request") do | me, req |
	  me.height_request = 12
	  me.width_request = 13
	end
	header_row.pack_start( Gtk::VBox.new.pack_start( left_upper_box, false ).pack_start( HGridLine.new, false ), false )
	header_row.pack_start( VGridLine.new, false )

	left_upper_box.signal_connect( "button_press_event" ) do |widget, event|
	  if event.kind_of? Gdk::EventButton
	    if (event.button == 3)
	      menu = Gtk::Menu.new
	          

	      menu.append( @gui.make_suggested_properties_menu( @top_column.viewed_values(), "existing properties", proc do | lens_part |
								 @lens_part['value_view_container_lens']['lens_parts'] << lens_part
							       end ) )

	      menu.append( @gui.make_type_properties_menu( @top_column.viewed_values(), "type properties", @lens_part['value_view_container_lens']['lens_parts'] ) )



	      if( @lens_part['show_filters'].to_s == 'true' )
		menu.append( GUI.create_menu_item( "hide filters", proc do
						    @lens_part['show_filters'] = 'false'
						  end ) )
	      else
		menu.append( GUI.create_menu_item( "show filters", proc do
						    @lens_part['show_filters'] = 'true'
						  end ) )
	      end

	      menu.append( GUI.create_menu_item( "add new property", proc do
						  @lens_part['value_view_container_lens']['lens_parts'] << GUI::create_lens_part()
						end ) )

	      menu.append( @gui.generate_lens_part_menu(@value, @top_column.lens_part ) )

# 	      menu.append( GUI.create_menu_item( "save table", proc do 
# 						  @gui.add_history_value( to_value( @gui.kaivo ) )
# 						end ) )
# 	      menu.append( GUI.create_menu_item( "save table as new value", proc do 
# 						  @gui.add_history_value( to_value( @gui.kaivo, @gui.kaivo.generate_value() ) )
# 						end ) )
	      menu.show_all
	      menu.popup(nil,nil,event.button,event.time)
	      true
	    end
	  end
	end

#	header_row.pack_start( VGridLine.new, false )


	header_box = HeaderBox.new( @gui, @top_column )

	@filter_box = FilterBox.new( @gui, @top_column)
	@filter_box.show_all()
	@filter_box.no_show_all = true
	header_row.pack_start( Gtk::VBox.new.pack_start(header_box, false).pack_start( @filter_box, false ) , false)

	if( @lens_part['show_filters'].to_s == 'true' )
	  @filter_box.show()
	else
	  @filter_box.hide()
	end
	
	@lens_part.add_observer( Observer.new( proc do | changed_property |
						if( changed_property == 'show_filters' )
						  if( @lens_part['show_filters'].to_s == 'true' )
						    @filter_box.show()
						  else
						    @filter_box.hide()
						  end
						end
					      end ) )
	

	pack_start(header_row, false)

	@header_size_group =  Gtk::SizeGroup.new( Gtk::SizeGroup::VERTICAL )
	@header_size_group.add_widget( header_row )

#	pack_start( Gtk::HSeparator.new, false)

#	pack_start( Gtk::ScrolledWindow.new.add_with_viewport( Gtk::VBox.new.pack_start(@top_column,false) ).set_policy(Gtk::POLICY_NEVER,
#											 Gtk::POLICY_AUTOMATIC ) , true )

	pack_start(Gtk::VBox.new.pack_start(@top_column,false))

#	add_column( StatementColumn.new() )
	
      end

      def first_column_value_view_container
	@top_column.first_value_view_container
      end

      def header_size_group
	@header_size_group
      end

      def add_column column
	@top_column.add_sub_column( column )
      end

      def set_predicate new_predicate
	@top_column.predicate = new_predicate
      end

      def set_value value
	@value = value
	@top_column.remove_value( 0 )
	@top_column.add_value( 0, value )
      end

      def header
	return Gtk::Label.new("Table")
      end

    end
  end
end
