require File.dirname(__FILE__) + "/common"

$LOAD_PATH.unshift File.dirname(__FILE__) + "/../devel"
require "jumpstart"

Jumpstart.doc_to_spec("README.rdoc", "Synopsis", "Raw Form", "Synopsis 2.0")
