require 'kaivo/kaivo'
require 'drb'

module BDB
  class Env
    include DRbUndumped
  end
end


module Kaivo
  class Kaivo
    include DRbUndumped
  end

  class Transaction
    include DRbUndumped
  end

  class Server
    def run database_name, port = ""
      @kaivo = Kaivo.new(database_name)
      DRb.start_service( "druby://:2001", @kaivo )
      puts DRb.uri
      puts "Hit enter to exit."
      STDIN.gets
      @kaivo.shut_down
    end

  end
end

server = Kaivo::Server.new
if(ARGV.size > 1)
  server.run(ARGV[0],ARGV[1])
else
  server.run(ARGV[0])
end
