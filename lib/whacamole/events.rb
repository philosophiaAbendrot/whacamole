module Whacamole
  module Events
    class Event
      attr_accessor :process

      def initialize(attributes={})
        attributes.each do |k,v|
          self.send("#{k}=", v)
        end
      end
    end
    
    class DynoRestart < Event
    end
  end
end

