defmodule Pocsync.Builtin.Log do
  require Logger

  def definition do
    %{
      name: "pocsync.log",
      description: "Logs data at info level",
      executor: {__MODULE__, :call, []},
      input_schema: %{
        type: "object",
        properties: %{
          input_data: %{
            type: "object",
            properties: %{
              message: %{type: "string", description: "Log message"},
              data: %{type: "object", description: "Additional data to log"}
            },
            required: ["message"]
          }
        },
        required: ["input_data"]
      }
    }
  end

  def call(input_data) do
    message = extract_message(input_data, "Pipeline step output")
    data = extract_data(input_data)

    formatted_message = format_log_message(message, data)
    Logger.info(formatted_message)
    Logger.info("Logging data: #{inspect(data, limit: 100)}")

    {:ok,
     %{
       success: true,
       logged_at: DateTime.utc_now() |> DateTime.to_iso8601(),
       level: "info",
       message: message,
       data: data
     }}
  end

  defp extract_message(input_data, default) do
    input_data["message"] || input_data[:message] ||
      get_in(input_data, ["pipeline_data", "message"]) ||
      get_in(input_data, [:pipeline_data, :message]) ||
      default
  end

  defp extract_data(input_data) do
    # Try to extract meaningful data to log
    cond do
      Map.has_key?(input_data, "data") or Map.has_key?(input_data, :data) ->
        input_data["data"] || input_data[:data]

      Map.has_key?(input_data, "pipeline_data") or Map.has_key?(input_data, :pipeline_data) ->
        input_data["pipeline_data"] || input_data[:pipeline_data]

      true ->
        # Filter out system keys and return remaining data
        input_data
        |> Map.drop(["message", :message, "context", :context])
        |> case do
          data when map_size(data) > 0 -> data
          _ -> nil
        end
    end
  end

  defp format_log_message(message, nil) do
    "[PIPELINE] #{message}"
  end

  defp format_log_message(message, data) do
    data_summary =
      case data do
        %{} when map_size(data) == 0 ->
          "empty map"

        %{} ->
          keys = Map.keys(data) |> Enum.take(5)

          key_summary =
            if length(keys) == 5, do: "#{Enum.join(keys, ", ")}...", else: Enum.join(keys, ", ")

          "map with keys: #{key_summary}"

        list when is_list(list) ->
          "list with #{length(list)} items"

        binary when is_binary(binary) ->
          "string (#{byte_size(binary)} bytes)"

        _ ->
          inspect(data, limit: 100)
      end

    "[PIPELINE] #{message} | Data: #{data_summary}"
  end
end
