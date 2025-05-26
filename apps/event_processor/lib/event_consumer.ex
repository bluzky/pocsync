defmodule EventProcessor.EventConsumer do
  use Broadway

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayRabbitMQ.Producer,
           queue: "inn_event_queue",
           connection: [
             host: "localhost",
             port: 5672,
             username: "guest",
             password: "guest"
           ],
           qos: [prefetch_count: 50]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: 10]
      ]
    )
  end

  @impl true
  def handle_message(_, message, _) do
    Logger.info("Received message: #{message.data}")

    # Your message processing logic here
    case Jason.decode(message.data) do
      {:ok, event} ->
        process_event(event)
        message

      {:error, reason} ->
        Logger.error("Failed to decode message: #{reason}")
        Broadway.Message.failed(message, reason)
    end
  end

  defp process_event(%{"type" => "user_created", "data" => user_data}) do
    Logger.info("Processing user created event: #{inspect(user_data)}")
    # Handle user creation logic
  end

  defp process_event(%{"type" => "order_placed", "data" => order_data}) do
    Logger.info("Processing order placed event: #{inspect(order_data)}")
    # Handle order placement logic
  end

  defp process_event(event) do
    Logger.warn("Unknown event type: #{inspect(event)}")
  end
end
