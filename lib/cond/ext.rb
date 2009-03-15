
require 'thread'

module Cond
  module Ext
    unless respond_to? :tap
      def tap
        yield self
        self
      end
    end
    
    unless respond_to? :let
      def let
        yield self
      end
    end
  end
end
