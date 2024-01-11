require 'drb'
require 'kaivo/gui'

module Kaivo
  class Observer
    include DRbUndumped
  end

#  class Transaction
#    include DRbUndumped
#  end

  module View
    class Table
      class StatementCell
	include DRbUndumped
      end
      class StatementRow
	include DRbUndumped
      end
    end
  end
end



DRb.start_service()
kaivo = DRbObject.new(nil, ARGV[0])
gui = Kaivo::GUI.new( kaivo )
gui.run
DRb.stop_service
