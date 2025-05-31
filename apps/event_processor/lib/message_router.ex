defmodule MessageRouter do
  @rules [
    %{
      queue: "lazada_pipeline_queue",
      pattern: %{
        "params" => %{
          "app_id" => "lazada"
        }
      }
    },
    %{
      queue: "default_pipeline_queue",
      pattern: %{}
    }
  ]

  def match(message) do
    Enum.find(@rules, fn rule ->
      DataMatcher.match?(message, rule.pattern)
    end)
    |> case do
      nil -> {:error, "No matching rule found"}
      rule -> {:ok, rule.queue}
    end
  end
end
