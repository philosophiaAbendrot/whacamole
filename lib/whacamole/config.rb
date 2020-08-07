module Whacamole
  class Config
    RESTART_RATE_LIMIT = 30*60

    attr_accessor :app_name, :api_token, :event_handler, :dynos, :restart_window

    def initialize(app_name)
      self.app_name = app_name
      self.event_handler ||= lambda { |e| puts e.inspect.to_s }
      self.dynos ||= %w{web}
      self.restart_window ||= RESTART_RATE_LIMIT
    end
  end
end
