require File.dirname(__FILE__) + '/cond_spec_base'

require 'levitate'

Levitate.doc_to_spec(
  "README.rdoc",
  "Synopsis",
  "DSL Form and Raw Form",
  "Synopsis 2.0"
)
