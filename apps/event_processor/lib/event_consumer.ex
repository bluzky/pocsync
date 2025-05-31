defmodule EventProcessor.EventConsumer do
  use Broadway

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayRabbitMQ.Producer,
           queue: System.get_env("RABBIT_EVENT_QUEUE", "inn_event_queue"),
           connection: [
             host: "localhost",
             port: 5672,
             username: "guest",
             password: "guest"
           ],
           on_failure: :ack,
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
    Logger.info("Received event message: #{message.data}")

    # Your message processing logic here
    case Jason.decode(message.data) do
      {:ok, event} ->
        # find all matched pipelines for the event
        messages =
          match_pipeline_event(event)
          |> Enum.map(fn pipeline ->
            %{
              pipeline: pipeline,
              context: event
            }
          end)

        case MessageRouter.match(event) do
          {:ok, queue} ->
            # enqueue the matched pipelines for processing
            Logger.info("Matched queue: #{queue}")
            Pocsync.RMQPublisher.send_messages(queue, messages)

          {:error, _message} ->
            Logger.error("No matching pipeline found for event: #{inspect(event)}")
        end

        message

      {:error, reason} ->
        Logger.error("Failed to decode message: #{reason}")
        Broadway.Message.failed(message, reason)
    end
  end

  defp match_pipeline_event(event) do
    DemoPipelines.all()
    |> Enum.filter(fn pipeline ->
      DataMatcher.match?(event, pipeline.pattern)
    end)
  end
end
