require 'kaivo/bdbkaivo'
require 'kaivo/gui'


@k = Kaivo::BDBKaivo.new(ARGV[0])


gui = Kaivo::GUI.new( @k )
gui.run


@k.shut_down
