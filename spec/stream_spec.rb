require 'spec_helper'

class EventHandler
  attr_accessor :events

  def process(event)
    events << event
  end

  def events
    @events ||= []
  end
end

class RestartHandler
  def restart(process)
    true
  end

  def dynos
    %w{web.1 web.2}
  end
end

describe Whacamole::Stream do
  let(:eh) { EventHandler.new }
  let(:restart_handler) { RestartHandler.new }
  let(:stream) do
    Whacamole::Stream.new("https://api.heroku.com/path/to/stream/stream", restart_handler, 1000) do |event|
      eh.process(event)
    end
  end

  describe "stream" do
    it "opens the url for streaming" do
      stream.watch
    end
  end

  describe "handle_chunk" do
    context "when Rack::Timeout error is not present" do
      it "should not trigger events" do
        stream.dispatch_handlers <<-CHUNK
          ## NEW LOG FORMAT
          2013-08-22T16:39:22.208103+00:00 heroku[router]: at=info method=GET path=/favicon.ico host=aisle50.com fwd="205.159.94.63" dyno=web.3 connect=1ms service=20ms status=200 bytes=894
          2013-08-22T16:39:22.224847+00:00 heroku[router]: at=info method=GET path=/ host=www.aisle50.com fwd="119.63.193.132" dyno=web.3 connect=1ms service=5ms status=301 bytes=0
          2013-08-22T16:39:22.919300+00:00 heroku[web.2]: source=web.2 dyno=heroku.772639.a334caa8-736c-48b3-bac2-d366f75d7fa0 sample#load_avg_1m=0.20 sample#load_avg_5m=0.33 sample#load_avg_15m=0.38
          2013-08-22T16:39:22.919536+00:00 heroku[web.2]: source=web.2 dyno=heroku.772639.a334caa8-736c-48b3-bac2-d366f75d7fa0 sample#memory_total=581.95MB sample#memory_rss=581.75MB sample#memory_cache=0.16MB sample#memory_swap=0.03MB sample#memory_pgpgin=0pages sample#memory_pgpgout=179329pages
          2013-08-22T16:39:22.919773+00:00 heroku[web.2]: source=web.2 dyno=heroku.772639.a334caa8-736c-48b3-bac2-d366f75d7fa0 sample#diskmbytes=0MB
          2013-08-22T16:39:23.045250+00:00 heroku[web.1]: source=web.1 dyno=heroku.772639.4c9dcf54-f339-4d81-9756-8dad47f178a4 sample#load_avg_1m=0.24 sample#load_avg_5m=0.59
          2013-08-22T16:39:23.045789+00:00 heroku[web.1]: source=web.1 dyno=heroku.772639.4c9dcf54-f339-4d81-9756-8dad47f178a4 sample#diskmbytes=0MB
          2013-08-22T16:39:23.364649+00:00 heroku[worker.1]: source=worker.1 dyno=heroku.772639.ae391b5d-e776-43f9-b056-360912563d61 sample#load_avg_1m=0.00 sample#load_avg_5m=0.01 sample#load_avg_15m=0.02

          ## OLD LOG FORMAT
          2013-08-30T14:39:57.132272+00:00 heroku[web.1]: source=heroku.772639.web.1.50578a75-9052-4e14-ac30-ba3686750017 measure=load_avg_1m val=0.00
          2013-08-30T14:39:57.132782+00:00 heroku[web.1]: source=heroku.772639.web.1.50578a75-9052-4e14-ac30-ba3686750017 measure=load_avg_15m val=0.20
          2013-08-30T14:39:57.133012+00:00 heroku[web.1]: source=heroku.772639.web.1.50578a75-9052-4e14-ac30-ba3686750017 measure=memory_total val=509 units=MB
        CHUNK

        expect(eh.events.length).to eq(0)
      end
    end

    context "when Rack::Timeout error is present" do
      it "should kick off a restart" do
        restart_handler.should_receive(:restart).with("web.1")

        stream.dispatch_handlers <<-CHUNK
          191 <190>1 2020-08-06T05:39:40.274419+00:00 app web.1 - - Rack::Timeout::RequestTimeoutException (Request waited 1018ms, then ran for longer than 15000ms )
          174 <190>1 2020-08-06T05:39:40.274568+00:00 app web.1 - - /app/vendor/bundle/ruby/2.2.0/gems/dalli-2.7.2/lib/dalli/socket.rb:9:in `select'
        CHUNK
      end

      it "should create a DynoRestart event." do
        stream.dispatch_handlers <<-CHUNK
          191 <190>1 2020-08-06T05:39:40.274419+00:00 app web.1 - - Rack::Timeout::RequestTimeoutException (Request waited 1018ms, then ran for longer than 15000ms )
          174 <190>1 2020-08-06T05:39:40.274568+00:00 app web.1 - - /app/vendor/bundle/ruby/2.2.0/gems/dalli-2.7.2/lib/dalli/socket.rb:9:in `select'
        CHUNK

        restart = eh.events.first
        expect(restart).to be_a Whacamole::Events::DynoRestart
        expect(restart.process).to eq "web.1"
      end
    end
  end
end