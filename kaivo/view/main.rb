require 'kaivo/view/text'
require 'kaivo/view/label'
require 'kaivo/view/suggest'
require 'kaivo/view/twostate'


module Kaivo
  module View

    class Main < Gtk::HBox

      def initialize gui
	super

	@gui = gui

	@notebook_left = Gtk::Notebook.new
	@notebook_right = Gtk::Notebook.new

	@notebook_right.scrollable = true
	@notebook_left.scrollable = true

	vpaned = Gtk::VPaned.new
	upper_hpaned = Gtk::HPaned.new
	upper_hpaned.add1 @notebook_left
	upper_hpaned.add2 @notebook_right

	vpaned.add1 upper_hpaned

	@uri_editor = Gtk::Entry.new()
	@uri_editor.signal_connect "key_press_event" do |widget,event|
	  if( event.keyval == Gdk::Keyval::GDK_Return )

	    add_history_value(@uri_editor.text)
	    @uri_editor.text = ""

	    true
	  end
	end
	@item_view = Gtk::VBox.new(false, 2)
	vb = Gtk::VBox.new

	ebox = Gtk::EventBox.new
	ebox.add( @item_view )
	ebox.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	vb.add(Gtk::ScrolledWindow.new.add_with_viewport( ebox ).set_policy(Gtk::POLICY_AUTOMATIC,
										  Gtk::POLICY_AUTOMATIC ))
	vb.pack_start(@uri_editor, false)

	Gtk::Drag.dest_set(@item_view, Gtk::Drag::DEST_DEFAULT_MOTION | 
			   Gtk::Drag::DEST_DEFAULT_HIGHLIGHT,
			   [["uri", Gtk::Drag::TARGET_SAME_APP, 1],
			     ["blank_id", Gtk::Drag::TARGET_SAME_APP, 2],
			     ["literal", Gtk::Drag::TARGET_SAME_APP, 3]],
			   Gdk::DragContext::ACTION_COPY|Gdk::DragContext::ACTION_MOVE)
	@item_view.signal_connect("drag-data-received") do |w, dc, x, y, selectiondata, info, time|
	  dc.targets.each do |target|
	    if target.name == "uri"
	      add_history_value(Redland::Node.new(Redland::Uri.new(selectiondata.data)))
	    elsif target.name == "blank_id"
	      add_history_value(Redland::BNode.new(selectiondata.data))
	    elsif target.name == "literal"
	      parts = selectiondata.data.split("^^")
	      add_history_value(Redland::Literal.new(parts[0], nil, Redland::Uri.new(parts[1])))
	    end
	  end
	end
	@item_view.signal_connect("drag-drop") do |w, dc, x, y, time|
	  Gtk::Drag.get_data(w, dc, dc.targets[0], time)
	end

	vpaned.add2( vb )

	add vpaned

      end

      def add_view book, view
	header_box = Gtk::HBox.new
	header_box.pack_start(view.header,true)
#	header_box.pack_start(Gtk::Label.new("table"),true)
	header_box_events = Gtk::EventBox.new.add(header_box)

        close_button = Gtk::Button.new
        close_button.set_border_width(0)
        close_button.set_size_request(16, 16)
        close_button.set_relief(Gtk::RELIEF_NONE)
        
        image = Gtk::Image.new
        image.set(:'gtk-close', Gtk::IconSize::MENU)
        close_button.add(image)

	header_box.pack_start(close_button,false)
	header_box.show_all

	ebox = Gtk::EventBox.new
	ebox.add( view )
	ebox.modify_bg(Gtk::STATE_NORMAL, Gdk::Color.new(65535,65535,65535))
	scrolled_view = Gtk::ScrolledWindow.new.add_with_viewport( ebox ).set_policy(Gtk::POLICY_AUTOMATIC,
										     Gtk::POLICY_AUTOMATIC )


	book.append_page(scrolled_view, header_box_events )
	scrolled_view.show_all
	book.page = book.page_num(scrolled_view)


 	Gtk::Drag.dest_set(header_box_events, Gtk::Drag::DEST_DEFAULT_MOTION,
 			   [["uri", Gtk::Drag::TARGET_SAME_APP, 1],
 			     ["blank_id", Gtk::Drag::TARGET_SAME_APP, 2],
 			   ["literal", Gtk::Drag::TARGET_SAME_APP, 3]],
 			   Gdk::DragContext::ACTION_COPY|Gdk::DragContext::ACTION_MOVE)

	header_box_events.signal_connect("drag-motion") do |s, drag_context, x, y, time|
	  book.page = book.page_num(scrolled_view)
	end

 	header_box_events.signal_connect("button_press_event") do |widget, event|
 	  if event.kind_of? Gdk::EventButton
 	    if (event.button == 3)
	      page_number = @notebook_left.page_num(scrolled_view)
	      if( page_number == -1 )
		page_number = @notebook_right.page_num(scrolled_view)
		@notebook_right.remove_page(page_number)
		@notebook_left.append_page(scrolled_view, header_box_events )
		@notebook_left.page = @notebook_left.page_num(scrolled_view)
	      else
		@notebook_left.remove_page(page_number)
		@notebook_right.append_page(scrolled_view, header_box_events )
		@notebook_right.page = @notebook_right.page_num(scrolled_view)
	      end
 	    end
 	  end
 	end

        close_button.signal_connect('clicked') do |widget, event|
	  page_number = @notebook_left.page_num(scrolled_view)
	  if( page_number == -1 )
	    page_number = @notebook_right.page_num(scrolled_view)
	    @notebook_right.remove_page(page_number)
	  else
	    @notebook_left.remove_page(page_number)
	  end
	  scrolled_view.destroy
	  header_box.destroy
        end

      end

      def close_all_views
	close_notebook( @notebook_left )
	close_notebook( @notebook_right )
      end

      def close_notebook notebook
	if(notebook.n_pages > 0)
	  [1 .. notebook.n_pages].each do
	    child = notebook.get_nth_page(0)
	    tab =  notebook.get_tab_label(child)
	    notebook.remove_page(0)
	    child.destroy
	    tab.destroy
	  end
	end
      end	

#      def move_left view
#	@notebook_right.remove_page(@notebook_right.page_num( view ) )
#	add_left( view )
#      end

      def add_left view
	add_view(@notebook_left, view)
      end

      def add_right view
	add_view(@notebook_right, view)
      end

      def add_log text
	add_history_view( Gtk::Alignment.new(0,0.5,0,0).add(Gtk::Label.new( text )) )
      end
      
      def add_history_value value
	add_history_view( TwoState.new( @gui, value, Label, [], Text, [] ) )
      end

      def add_history_view view

	@item_view.pack_end( view, false )

	if( @item_view.children.size > 10 )
	  last_child = @item_view.children[@item_view.children.size - 1]
	  @item_view.remove(last_child)
	  last_child.destroy
	end

	@item_view.show_all

      end

      def left_views
	@notebook_left.children.collect do | child | child.child.child end
      end

      def right_views
	@notebook_right.children.collect do | child | child.child.child end
      end


    end
  end
end
