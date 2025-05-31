defmodule PocsyncWeb.CallController do
  use PocsyncWeb, :controller

  alias AutomationPlatform.ExecutionResult

  @doc """
  Handles incoming API calls by delegating to the CallHandler.
  """
  def handle(conn, params) do
    event = %{
      "source" => "webhook",
      "path" => conn.request_path,
      "method" => conn.method,
      "params" => params,
      "headers" => conn.req_headers
    }

    case match_pipeline_event(event) do
      [] ->
        conn
        |> put_status(404)
        |> json(%{message: "No matching pipeline found"})

      [pipeline | _] ->
        result =
          AutomationPlatform.PipelineExecutor.execute(pipeline, %{
            "source" => event["source"],
            "path" => event["path"],
            "params" => event["params"],
            "headers" => event["headers"]
          })

        if ExecutionResult.success?(result) do
          data = ExecutionResult.final_output(result)
          json(conn, %{data: data})
        else
          conn
          |> put_status(400)
          |> json(%{error: result.error || "Pipeline execution failed"})
        end
    end
  end

  defp match_pipeline_event(event) do
    IO.inspect(event, label: "Matching event")

    DemoPipelines.all()
    |> Enum.filter(fn pipeline ->
      DataMatcher.match?(event, pipeline.pattern)
    end)
  end
end
