require 'net/http'

module Whacamole

  class Stream

    def initialize(url, restart_handler, &blk)
      @url = url
      @restart_handler = restart_handler
      @dynos = restart_handler.dynos
      @event_handler = blk
    end

    def watch
      uri = URI(url)
      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        http.request(request) do |response|
          response.read_body do |chunk|
            dispatch_handlers(chunk)
          end
        end
      end
    end

    def dispatch_handlers(chunk)
      rack_timeout_from_chunk(chunk).each do |dyno|
        restart(dyno)
      end

      # TODO: handle R14 errors here also
    end

    private
    def restart(process)
      restarted = restart_handler.restart(process)

      if restarted
        event_handler.call( Events::DynoRestart.new({:process => process}) )
      end
    end

    def rack_timeout_from_chunk(chunk)
      dynos_regexp = Regexp.new('(' + @dynos.join("|") + ').+')

      dynos = []

      chunk.split("\n").select { |line| line.include? "Rack::Timeout" }.each do |line|
        dyno = line.match(dynos_regexp)
        next unless dyno
        dynos << dyno[1]
      end

      dynos
    end

    def url
      @url
    end

    def event_handler
      @event_handler
    end

    def restart_handler
      @restart_handler
    end
  end
end
