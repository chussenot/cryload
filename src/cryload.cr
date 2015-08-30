require "./cryload/*"
require "http"
require "colorize"
require "option_parser"

module Cryload
  # LoadGenerator is the main class in Cryload. It's responsible for generating
  # the requests and other major stuff.
  class LoadGenerator
    # LoadGenerator accepts two params.
    # @host :: String
    # @number :: Int32
    def initialize(@host, @number)
      @stats = Stats.new @number
      channel = generate_request_channel
      spawn_receive_loop channel
    end

    # Generates a Channel for asynchronously sending HTTP requests.
    def generate_request_channel()
      channel = Channel(Nil).new
      spawn_request_loop channel
      channel
    end

    # Spawns the main loop which creates the HTTP client. The HTTP clients
    # sends HTTP::get requests to the specified host. It doesn't block
    # the main program and send the completion of the request to channel.
    def spawn_request_loop(channel)
      uri = parse_uri
      client = create_http_client uri
      spawn do
        loop do
          get_response(client, uri)
          channel.send nil
        end
      end
    end

    # Spawns the receiver loop which listens the send events from channel.
    # This loop is also responsible for checking the logs and gathering stats
    # about all the completed requests.
    def spawn_receive_loop(channel)
      loop do
        check_log
        channel.receive
      end
    end

    private def parse_uri
      uri = URI.parse @host
    end

    private def create_http_client(uri)
      HTTP::Client.new uri.host.not_nil!, port: uri.port, ssl: uri.scheme == "https"
    end

    private def get_response(client, uri)
      start_time = Time.now
      response = client.get uri.full_path
      end_time = Time.now
      request = Request.new start_time, end_time, response.status_code
      @stats.requests << request
    end

    private def check_log
      Logger.new @stats
    end
  end
end

Cryload::Cli.new
