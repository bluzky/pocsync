defmodule AutomationPlatform.Pipeline do
  @moduledoc """
  Represents a complete automation pipeline with ordered steps
  """
  @derive Jason.Encoder

  defstruct [
    :id,
    :name,
    :description,
    :steps,
    :status,
    :created_at,
    :updated_at
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          description: String.t() | nil,
          steps: [AutomationPlatform.Step.t()],
          status: :active | :inactive | :draft,
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @doc """
  Creates a new pipeline with default values
  """
  def new(name, description \\ nil) do
    %__MODULE__{
      id: generate_id(),
      name: name,
      description: description,
      steps: [],
      status: :draft,
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Adds a step to the pipeline
  """
  def add_step(%__MODULE__{steps: steps} = pipeline, step) do
    updated_steps = steps ++ [step]
    %{pipeline | steps: updated_steps, updated_at: DateTime.utc_now()}
  end

  @doc """
  Inserts a step at a specific position
  """
  def insert_step(%__MODULE__{steps: steps} = pipeline, step, position) do
    updated_steps = List.insert_at(steps, position, step)
    %{pipeline | steps: updated_steps, updated_at: DateTime.utc_now()}
  end

  @doc """
  Removes a step by position
  """
  def remove_step(%__MODULE__{steps: steps} = pipeline, position) when position >= 0 do
    updated_steps = List.delete_at(steps, position)
    %{pipeline | steps: updated_steps, updated_at: DateTime.utc_now()}
  end

  @doc """
  Gets step by position (0-indexed)
  """
  def get_step(%__MODULE__{steps: steps}, position) when position >= 0 do
    Enum.at(steps, position)
  end

  @doc """
  Gets step by ID
  """
  def get_step_by_id(%__MODULE__{steps: steps}, step_id) do
    Enum.find(steps, &(&1.id == step_id))
  end

  @doc """
  Updates pipeline status
  """
  def update_status(%__MODULE__{} = pipeline, status)
      when status in [:active, :inactive, :draft] do
    %{pipeline | status: status, updated_at: DateTime.utc_now()}
  end

  @doc """
  Validates pipeline structure
  """
  def valid?(%__MODULE__{steps: steps}) do
    steps
    |> Enum.with_index()
    |> Enum.all?(fn {step, index} ->
      AutomationPlatform.Step.valid?(step) and step.position == index
    end)
  end

  @doc """
  Reorders steps based on position field
  """
  def reorder_steps(%__MODULE__{steps: steps} = pipeline) do
    ordered_steps =
      steps
      |> Enum.sort_by(& &1.position)
      |> Enum.with_index()
      |> Enum.map(fn {step, index} -> %{step | position: index} end)

    %{pipeline | steps: ordered_steps, updated_at: DateTime.utc_now()}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end

  def encode(%__MODULE__{} = pipeline) do
    Jason.encode!(pipeline)
  end

  def decode(data) do
    %__MODULE__{
      id: Map.get(data, "id"),
      name: Map.get(data, "name"),
      description: Map.get(data, "description"),
      steps: Enum.map(Map.get(data, "steps", []), &AutomationPlatform.Step.decode/1),
      status: String.to_existing_atom(Map.get(data, "status", "draft")),
      created_at: DateTime.from_iso8601(Map.get(data, "created_at")),
      updated_at: DateTime.from_iso8601(Map.get(data, "updated_at"))
    }
  end
end

defmodule AutomationPlatform.Step do
  @moduledoc """
  Represents a single step/node in a pipeline with integration-based actions
  """

  @derive Jason.Encoder

  defstruct [
    :id,
    :name,
    :type,
    :integration_name,
    :action_name,
    :input_map,
    :position
  ]

  @type step_type :: :trigger | :action | :output

  @type t :: %__MODULE__{
          id: String.t() | nil,
          name: String.t(),
          type: step_type(),
          integration_name: String.t(),
          action_name: String.t(),
          input_map: map(),
          position: integer()
        }

  @doc """
  Creates a new step
  """
  def new(name, type, integration_name, action_name, input_map \\ %{}, position \\ 0) do
    %__MODULE__{
      id: generate_id(),
      name: name,
      type: type,
      integration_name: integration_name,
      action_name: action_name,
      input_map: input_map,
      position: position
    }
  end

  @doc """
  Creates a step from integration and action names - user defines the integration/action
  """
  def from_integration(name, type, integration_name, action_name, input_map \\ %{}, position \\ 0) do
    new(name, type, integration_name, action_name, input_map, position)
  end

  @doc """
  Validates that the step's action exists in the registry
  """
  def valid?(%__MODULE__{integration_name: integration, action_name: action}) do
    case AutomationPlatform.IntegrationRegistry.get_action(integration, action) do
      {:ok, _action_def} -> true
      {:error, :not_found} -> false
    end
  end

  @doc """
  Updates step input map
  """
  def update_input(%__MODULE__{} = step, new_input_map) do
    %{step | input_map: new_input_map}
  end

  @doc """
  Merges additional input into existing input map
  """
  def merge_input(%__MODULE__{input_map: current_input} = step, additional_input) do
    merged_input = Map.merge(current_input, additional_input)
    %{step | input_map: merged_input}
  end

  @doc """
  Updates step position
  """
  def update_position(%__MODULE__{} = step, new_position) when new_position >= 0 do
    %{step | position: new_position}
  end

  @doc """
  Gets the action definition for this step from the registry
  """
  def get_action_definition(%__MODULE__{integration_name: integration, action_name: action}) do
    AutomationPlatform.IntegrationRegistry.get_action(integration, action)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end

  def decode(map) do
    %__MODULE__{
      id: Map.get(map, "id"),
      name: Map.get(map, "name"),
      type: String.to_existing_atom(Map.get(map, "type", "action")),
      integration_name: Map.get(map, "integration_name"),
      action_name: Map.get(map, "action_name"),
      input_map: Map.get(map, "input_map", %{}),
      position: Map.get(map, "position", 0)
    }
  end
end
