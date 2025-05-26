defmodule EventProcessor.PipelineConsumer do
  use Broadway

  require Logger

  def start_link(_opts) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {BroadwayRabbitMQ.Producer,
           queue: "inn_pipeline_queue",
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
    # Your message processing logic here
    case Jason.decode(message.data) do
      {:ok,
       %{
         "pipeline" => pipeline_data,
         "context" => context
       }} ->
        pipeline = AutomationPlatform.Pipeline.decode(pipeline_data)
        Logger.info(">>> Process pipeline: #{pipeline.id} - #{pipeline.name}")
        AutomationPlatform.PipelineExecutor.execute(pipeline, context)
        message

      {:error, reason} ->
        Logger.error("Failed to decode message: #{reason}")
        Broadway.Message.failed(message, reason)
    end
  end
end
