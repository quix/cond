$VERBOSE = false  # harmless warnings due to symlinked requires
$LOAD_PATH.unshift "./lib"
$LOAD_PATH.unshift "./contrib/quix/lib"
require 'quix/simple_installer'
Cond::SimpleInstaller.new.run
