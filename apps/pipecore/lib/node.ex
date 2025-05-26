defmodule PipeCore.Step do
  @moduledoc """
  Represents a single step/node in a pipeline
  """

  defstruct [
    :id,
    :name,
    :type,
    :integration,
    :config,
    :input_schema,
    :output_schema,
    :position
  ]

  @type step_type :: :trigger | :action | :output
  @type integration_type :: :http | :scheduler | :pipeline

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          type: step_type(),
          integration: integration_type(),
          config: map(),
          input_schema: map() | nil,
          output_schema: map() | nil,
          position: integer()
        }

  @doc """
  Creates a new step
  """
  def new(name, type, integration, config \\ %{}, position \\ 0) do
    %__MODULE__{
      id: generate_id(),
      name: name,
      type: type,
      integration: integration,
      config: config,
      input_schema: default_input_schema(type, integration),
      output_schema: default_output_schema(type, integration),
      position: position
    }
  end

  @doc """
  Creates a webhook trigger step
  """
  def webhook_trigger(name, config \\ %{}) do
    new(name, :trigger, :http, Map.merge(%{method: "POST"}, config))
  end

  @doc """
  Creates an HTTP API call action step
  """
  def http_action(name, config) do
    new(name, :action, :http, config)
  end

  @doc """
  Creates a log output step
  """
  def log_output(name, config \\ %{}) do
    new(name, :output, :http, Map.merge(%{action: "log"}, config))
  end

  @doc """
  Validates step configuration based on type and integration
  """
  def valid?(%__MODULE__{type: :trigger, integration: :http, config: config}) do
    Map.has_key?(config, :method)
  end

  def valid?(%__MODULE__{type: :action, integration: :http, config: config}) do
    Map.has_key?(config, :url) and Map.has_key?(config, :method)
  end

  def valid?(%__MODULE__{type: :output, integration: :http, config: config}) do
    Map.has_key?(config, :action)
  end

  def valid?(_), do: false

  # Default schemas based on step type and integration
  defp default_input_schema(:trigger, :http) do
    %{
      "type" => "object",
      "properties" => %{
        "body" => %{"type" => "object"},
        "headers" => %{"type" => "object"},
        "query_params" => %{"type" => "object"}
      }
    }
  end

  defp default_input_schema(:action, :http) do
    %{
      "type" => "object",
      "properties" => %{
        "data" => %{"type" => "object"}
      }
    }
  end

  defp default_input_schema(:output, :http) do
    %{
      "type" => "object",
      "properties" => %{
        "result" => %{"type" => "object"}
      }
    }
  end

  defp default_output_schema(:trigger, :http) do
    %{
      "type" => "object",
      "properties" => %{
        "trigger_data" => %{"type" => "object"},
        "timestamp" => %{"type" => "string", "format" => "date-time"}
      }
    }
  end

  defp default_output_schema(:action, :http) do
    %{
      "type" => "object",
      "properties" => %{
        "response" => %{"type" => "object"},
        "status_code" => %{"type" => "integer"},
        "headers" => %{"type" => "object"}
      }
    }
  end

  defp default_output_schema(:output, :http) do
    %{
      "type" => "object",
      "properties" => %{
        "success" => %{"type" => "boolean"},
        "message" => %{"type" => "string"}
      }
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end
end
