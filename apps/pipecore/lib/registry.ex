defmodule AutomationPlatform.IntegrationRegistry do
  @moduledoc """
  Registry for managing integrations and their available actions
  """

  use GenServer
  require Logger

  defstruct [:integrations, :modules]

  @type action_executor :: {module(), atom(), list()}

  @type action_definition :: %{
          name: String.t(),
          description: String.t(),
          executor: action_executor(),
          input_schema: map(),
          output_schema: map()
        }

  @type integration_definition :: %{
          name: String.t(),
          description: String.t(),
          actions: %{String.t() => action_definition()}
        }

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      %__MODULE__{integrations: opts[:integrations] || %{}},
      opts ++ [name: __MODULE__]
    )
  end

  @doc """
  Registers an integration with its actions
  """
  def register_integration(integration_name, definition) do
    GenServer.call(__MODULE__, {:register_integration, integration_name, definition})
  end

  @doc """
  Gets an action definition by integration and action name
  """
  def get_action(integration_name, action_name) do
    GenServer.call(__MODULE__, {:get_action, integration_name, action_name})
  end

  @doc """
  Lists all available integrations
  """
  def list_integrations do
    GenServer.call(__MODULE__, :list_integrations)
  end

  @doc """
  Lists all actions for a specific integration
  """
  def list_actions(integration_name) do
    GenServer.call(__MODULE__, {:list_actions, integration_name})
  end

  @doc """
  Gets complete integration definition
  """
  def get_integration(integration_name) do
    GenServer.call(__MODULE__, {:get_integration, integration_name})
  end

  # Server callbacks

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_call({:register_integration, name, definition}, _from, state) do
    updated_integrations = Map.put(state.integrations, name, definition)
    new_state = %{state | integrations: updated_integrations}

    Logger.info("Registered integration: #{name} with #{map_size(definition.actions)} actions")
    {:reply, :ok, new_state}
  end

  def handle_call({:get_action, integration_name, action_name}, _from, state) do
    result =
      case get_in(state.integrations, [integration_name, :actions, action_name]) do
        nil -> {:error, :not_found}
        action -> {:ok, action}
      end

    {:reply, result, state}
  end

  def handle_call({:get_integration, integration_name}, _from, state) do
    result =
      case Map.get(state.integrations, integration_name) do
        nil -> {:error, :not_found}
        integration -> {:ok, integration}
      end

    {:reply, result, state}
  end

  def handle_call(:list_integrations, _from, state) do
    integrations =
      state.integrations
      |> Enum.map(fn {name, def} ->
        %{name: name, description: def.description, action_count: map_size(def.actions)}
      end)

    {:reply, integrations, state}
  end

  def handle_call({:list_actions, integration_name}, _from, state) do
    actions =
      case Map.get(state.integrations, integration_name) do
        nil ->
          []

        integration ->
          integration.actions
          |> Enum.map(fn {name, def} ->
            %{name: name, description: def.description, input_schema: def.input_schema}
          end)
      end

    {:reply, actions, state}
  end
end
