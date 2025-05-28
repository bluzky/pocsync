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

        # enqueue the matched pipelines for processing
        Pocsync.RMQPublisher.send_messages("inn_pipeline_queue", messages)

        message

      {:error, reason} ->
        Logger.error("Failed to decode message: #{reason}")
        Broadway.Message.failed(message, reason)
    end
  end

  defp match_pipeline_event(event) do
    list_pipelines()
    |> Enum.filter(fn pipeline ->
      DataMatcher.match?(event, pipeline.pattern)
    end)
  end

  defp list_pipelines() do
    AutomationPlatform.Pipeline.list_pipelines()
  end
end
