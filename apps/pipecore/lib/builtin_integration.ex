defmodule AutomationPlatform.Integrations.Log do
  @moduledoc """
  Logging integration for output and debugging steps
  """

  require Logger

  @doc """
  Logs data at info level
  """
  def info(input_data) do
    message = extract_message(input_data, "Pipeline step output")
    data = extract_data(input_data)

    formatted_message = format_log_message(message, data)
    Logger.info(formatted_message)

    {:ok,
     %{
       success: true,
       logged_at: DateTime.utc_now() |> DateTime.to_iso8601(),
       level: "info",
       message: message,
       data: data
     }}
  end

  @doc """
  Logs data at error level
  """
  def error(input_data) do
    message = extract_message(input_data, "Pipeline step error")
    data = extract_data(input_data)

    formatted_message = format_log_message(message, data)
    Logger.error(formatted_message)

    {:ok,
     %{
       success: true,
       logged_at: DateTime.utc_now() |> DateTime.to_iso8601(),
       level: "error",
       message: message,
       data: data
     }}
  end

  @doc """
  Logs data at warning level
  """
  def warning(input_data) do
    message = extract_message(input_data, "Pipeline step warning")
    data = extract_data(input_data)

    formatted_message = format_log_message(message, data)
    Logger.warning(formatted_message)

    {:ok,
     %{
       success: true,
       logged_at: DateTime.utc_now() |> DateTime.to_iso8601(),
       level: "warning",
       message: message,
       data: data
     }}
  end

  @doc """
  Logs data at debug level
  """
  def debug(input_data) do
    message = extract_message(input_data, "Pipeline step debug")
    data = extract_data(input_data)

    formatted_message = format_log_message(message, data)
    Logger.debug(formatted_message)

    {:ok,
     %{
       success: true,
       logged_at: DateTime.utc_now() |> DateTime.to_iso8601(),
       level: "debug",
       message: message,
       data: data
     }}
  end

  # Helper functions

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

defmodule AutomationPlatform.Integrations.Transform do
  @moduledoc """
  Data transformation integration for processing pipeline data
  """

  require Logger

  @doc """
  Extracts specific fields from input data
  """
  def extract_fields(input_data) do
    fields = input_data["fields"] || input_data[:fields] || []
    source_data = input_data["pipeline_data"] || input_data[:pipeline_data] || input_data

    Logger.debug("Extracting fields", fields: fields, source_keys: Map.keys(source_data || %{}))

    extracted =
      case source_data do
        %{} when is_map(source_data) ->
          Enum.reduce(fields, %{}, fn field, acc ->
            value = Map.get(source_data, field) || Map.get(source_data, to_string(field))
            if value, do: Map.put(acc, field, value), else: acc
          end)

        _ ->
          %{}
      end

    {:ok, extracted}
  end

  @doc """
  Maps field names from input to output format
  """
  def map_fields(input_data) do
    field_mapping = input_data["mapping"] || input_data[:mapping] || %{}
    source_data = input_data["pipeline_data"] || input_data[:pipeline_data] || input_data

    Logger.debug("Mapping fields",
      mapping: field_mapping,
      source_keys: Map.keys(source_data || %{})
    )

    mapped =
      case source_data do
        %{} when is_map(source_data) ->
          Enum.reduce(field_mapping, %{}, fn {source_field, target_field}, acc ->
            value =
              Map.get(source_data, source_field) || Map.get(source_data, to_string(source_field))

            if value, do: Map.put(acc, target_field, value), else: acc
          end)

        _ ->
          %{}
      end

    {:ok, mapped}
  end

  @doc """
  Filters data based on conditions
  """
  def filter_data(input_data) do
    conditions = input_data["conditions"] || input_data[:conditions] || %{}
    source_data = input_data["pipeline_data"] || input_data[:pipeline_data] || input_data

    Logger.debug("Filtering data", conditions: conditions)

    passes_filter =
      Enum.all?(conditions, fn {field, expected_value} ->
        actual_value = Map.get(source_data, field) || Map.get(source_data, to_string(field))
        actual_value == expected_value
      end)

    result =
      if passes_filter do
        source_data
      else
        %{filtered_out: true, reason: "Failed filter conditions"}
      end

    {:ok,
     %{
       data: result,
       passed_filter: passes_filter,
       conditions_checked: conditions
     }}
  end

  @doc """
  Adds timestamp and metadata to data
  """
  def enrich_data(input_data) do
    source_data = input_data["pipeline_data"] || input_data[:pipeline_data] || input_data
    metadata = input_data["metadata"] || input_data[:metadata] || %{}

    enriched =
      Map.merge(source_data || %{}, %{
        "_enriched_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
        "_metadata" => metadata,
        "_pipeline_step" => "data_enrichment"
      })

    {:ok, enriched}
  end
end
