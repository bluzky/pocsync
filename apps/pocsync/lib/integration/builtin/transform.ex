defmodule Pocsync.Builtin.Transform do
  @moduledoc """
  Data transformation integration for processing pipeline data
  """

  require Logger

  def definition do
    [
      %{
        name: "pocsync.transform.extract_fields",
        description: "Extract specific fields from input data",
        executor: {__MODULE__, :extract_fields, []},
        input_schema: %{
          "type" => "object",
          "required" => ["fields"],
          "properties" => %{
            "fields" => %{"type" => "array", "items" => %{"type" => "string"}}
          }
        },
        output_schema: %{
          "type" => "object"
        }
      },
      %{
        name: "pocsync.transform.map_fields",
        description: "Map field names from input to output format",
        executor: {__MODULE__, :map_fields, []},
        input_schema: %{
          "type" => "object",
          "required" => ["mapping"],
          "properties" => %{
            "mapping" => %{"type" => "object", "description" => "Field mapping object"}
          }
        },
        output_schema: %{
          "type" => "object"
        }
      },
      %{
        name: "pocsync.transform.filter_data",
        description: "Filter data based on conditions",
        executor: {__MODULE__, :filter_data, []},
        input_schema: %{
          "type" => "object",
          "required" => ["conditions"],
          "properties" => %{
            "conditions" => %{"type" => "object", "description" => "Filter conditions"}
          }
        },
        output_schema: %{
          "type" => "object",
          "properties" => %{
            "data" => %{"type" => "object"},
            "passed_filter" => %{"type" => "boolean"}
          }
        }
      }
    ]
  end

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
