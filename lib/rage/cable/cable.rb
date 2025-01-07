# frozen_string_literal: true

module Rage::Cable
  # Create a new Cable application.
  #
  # @example
  #   map "/cable" do
  #     run Rage.cable.application
  #   end
  def self.application
    protocol = Rage.config.cable.protocol
    protocol.init(__router)

    handler = __build_handler(protocol)
    accept_response = [0, protocol.protocol_definition, []]

    application = ->(env) do
      if env["rack.upgrade?"] == :websocket
        env["rack.upgrade"] = handler
        accept_response
      else
        [426, { "Connection" => "Upgrade", "Upgrade" => "websocket" }, []]
      end
    end

    Rage.with_middlewares(application, Rage.config.cable.middlewares)
  end

  # @private
  def self.__router
    @__router ||= Router.new
  end

  # @private
  def self.__build_handler(protocol)
    klass = Class.new do
      def initialize(protocol)
        Iodine.on_state(:on_start) do
          unless Fiber.scheduler
            Fiber.set_scheduler(Rage::FiberScheduler.new)
          end
        end

        @protocol = protocol
      end

      def on_open(connection)
        Fiber.schedule do
          @protocol.on_open(connection)
        rescue => e
          log_error(e)
        end
      end

      def on_message(connection, data)
        Fiber.schedule do
          @protocol.on_message(connection, data)
        rescue => e
          log_error(e)
        end
      end

      if protocol.respond_to?(:on_close)
        def on_close(connection)
          return unless ::Iodine.running?

          Fiber.schedule do
            @protocol.on_close(connection)
          rescue => e
            log_error(e)
          end
        end
      end

      if protocol.respond_to?(:on_shutdown)
        def on_shutdown(connection)
          @protocol.on_shutdown(connection)
        rescue => e
          log_error(e)
        end
      end

      private

      def log_error(e)
        Rage.logger.error("Unhandled exception has occured - #{e.class} (#{e.message}):\n#{e.backtrace.join("\n")}")
      end
    end

    klass.new(protocol)
  end

  # Broadcast data directly to a named stream.
  #
  # @param stream [String] the name of the stream
  # @param data [Object] the object to send to the clients. This will later be encoded according to the protocol used.
  # @example
  #   Rage.cable.broadcast("chat", { message: "A new member has joined!" })
  def self.broadcast(stream, data)
    Rage.config.cable.protocol.broadcast(stream, data)
  end

  # @!parse [ruby]
  #   # @abstract
  #   class WebSocketConnection
  #     # Write data to the connection.
  #     #
  #     # @param data [String] the data to write
  #     def write(data)
  #     end
  #
  #     # Subscribe to a channel.
  #     #
  #     # @param name [String] the channel name
  #     def subscribe(name)
  #     end
  #
  #     # Close the connection.
  #     def close
  #     end
  #   end

  module Adapters
    autoload :Base, "rage/cable/adapters/base"
    autoload :Redis, "rage/cable/adapters/redis"
  end

  module Protocol
  end
end

require_relative "protocol/actioncable_v1_json"
require_relative "channel"
require_relative "connection"
require_relative "router"
