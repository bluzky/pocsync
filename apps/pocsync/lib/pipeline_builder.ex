defmodule Pocsync.PipelineBuilder do
  @moduledoc """
  Helper functions for building pipelines dynamically based on user configuration
  """

  alias AutomationPlatform.{Pipeline, Step}

  @doc """
  Creates a pipeline from a user configuration map

  Example config:
  %{
    name: "User Sync Pipeline",
    description: "Webhook triggered API call with logging",
    steps: [
      %{
        name: "Webhook Trigger",
        type: :trigger,
        integration_name: "pocsync.http",
        action_name: "pocsync.http.webhook_trigger",
        input_map: %{}
      },
      %{
        name: "API Call",
        type: :action,
        integration_name: "pocsync.http",
        action_name: "pocsync.http.post",
        input_map: %{
          url: "https://api.example.com/users",
          headers: %{"Authorization" => "Bearer token"}
        }
      },
      %{
        name: "Log Result",
        type: :output,
        integration_name: "pocsync.log",
        action_name: "pocsync.log.info",
        input_map: %{message: "Pipeline completed"}
      }
    ]
  }
  """
  def from_config(config) do
    pipeline = Pipeline.new(config.name, config[:description], config[:pattern])

    steps =
      config.steps
      |> Enum.with_index()
      |> Enum.map(fn {step_config, index} ->
        Step.from_integration(
          step_config.name,
          step_config.type,
          step_config.integration_name,
          step_config.action_name,
          step_config[:input_map] || %{},
          index
        )
      end)

    Enum.reduce(steps, pipeline, &Pipeline.add_step(&2, &1))
  end

  @doc """
  Creates a simple webhook -> API call -> log pipeline (backward compatibility)
  """
  def webhook_to_api_pipeline(name, api_url, api_headers \\ %{}) do
    config = %{
      name: name,
      description: "Webhook triggered API call with logging",
      steps: [
        %{
          name: "Webhook Trigger",
          type: :trigger,
          integration_name: "pocsync.http",
          action_name: "pocsync.http.webhook_trigger",
          input_map: %{}
        },
        %{
          name: "API Call",
          type: :action,
          integration_name: "pocsync.http",
          action_name: "pocsync.http.post",
          input_map: %{
            url: api_url,
            headers: api_headers
          }
        },
        %{
          name: "Log Result",
          type: :output,
          integration_name: "pocsync.log",
          action_name: "pocsync.log.info",
          input_map: %{
            message: "Pipeline execution completed"
          }
        }
      ]
    }

    from_config(config)
  end

  @doc """
  Creates a data transformation pipeline
  """
  def data_transformation_pipeline(name, source_url, destination_url) do
    config = %{
      name: name,
      description: "Fetch data, transform, and send to destination",
      steps: [
        %{
          name: "Fetch Data",
          type: :action,
          integration_name: "pocsync.http",
          action_name: "pocsync.http.get",
          input_map: %{
            url: source_url,
            headers: %{"Accept" => "application/json"}
          }
        },
        %{
          name: "Transform Data",
          type: :action,
          integration_name: "pocsync.transform",
          action_name: "pocsync.transform.map_fields",
          input_map: %{
            mapping: %{"old_field" => "new_field"}
          }
        },
        %{
          name: "Send to Destination",
          type: :action,
          integration_name: "pocsync.http",
          action_name: "pocsync.http.post",
          input_map: %{
            url: destination_url,
            headers: %{"Content-Type" => "application/json"}
          }
        },
        %{
          name: "Log Completion",
          type: :output,
          integration_name: "pocsync.log",
          action_name: "pocsync.log.info",
          input_map: %{
            message: "Data transformation pipeline completed"
          }
        }
      ]
    }

    from_config(config)
  end

  @doc """
  Validates a pipeline configuration before building
  """
  def validate_config(config) do
    with :ok <- validate_required_fields(config),
         :ok <- validate_steps(config.steps) do
      {:ok, config}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Lists all available actions from all integrations for pipeline building
  """
  def list_available_actions do
    case AutomationPlatform.IntegrationRegistry.list_integrations() do
      integrations when is_list(integrations) ->
        Enum.flat_map(integrations, fn %{name: integration_name} ->
          case AutomationPlatform.IntegrationRegistry.list_actions(integration_name) do
            actions when is_list(actions) ->
              Enum.map(actions, fn action ->
                %{
                  integration_name: integration_name,
                  action_name: action.name,
                  description: action.description,
                  input_schema: action.input_schema
                }
              end)

            _ ->
              []
          end
        end)

      _ ->
        []
    end
  end

  # Private validation functions

  defp validate_required_fields(config) do
    required_fields = [:name, :steps]
    missing_fields = Enum.reject(required_fields, &Map.has_key?(config, &1))

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_steps(steps) when is_list(steps) and length(steps) > 0 do
    steps
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {step, index}, _acc ->
      case validate_step(step, index) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, "Step #{index}: #{reason}"}}
      end
    end)
  end

  defp validate_steps(_), do: {:error, "Steps must be a non-empty list"}

  defp validate_step(step, _index) do
    required_step_fields = [:name, :type, :integration_name, :action_name]
    missing_fields = Enum.reject(required_step_fields, &Map.has_key?(step, &1))

    cond do
      not Enum.empty?(missing_fields) ->
        {:error, "Missing required step fields: #{Enum.join(missing_fields, ", ")}"}

      step.type not in [:trigger, :action, :output] ->
        {:error, "Invalid step type: #{step.type}. Must be :trigger, :action, or :output"}

      true ->
        # Validate that the integration/action exists
        case AutomationPlatform.IntegrationRegistry.get_action(
               step.integration_name,
               step.action_name
             ) do
          {:ok, _} ->
            :ok

          {:error, :not_found} ->
            {:error, "Action not found: #{step.integration_name}.#{step.action_name}"}
        end
    end
  end
end
