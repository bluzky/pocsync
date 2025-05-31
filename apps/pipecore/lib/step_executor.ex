defmodule AutomationPlatform.StepExecutor do
  @moduledoc """
  Executes individual steps by looking up actions in the integration registry
  and invoking their MFA executors with merged input data
  """

  require Logger
  alias AutomationPlatform.{Step, IntegrationRegistry}

  @doc """
  Executes a step by looking up the action in the registry and invoking its executor
  """
  def execute(%Step{} = step, pipeline_data, context \\ %{}) do
    Logger.debug("Executing step",
      step_id: step.id,
      step_name: step.name,
      integration: step.integration_name,
      action: step.action_name
    )

    case IntegrationRegistry.get_action(step.integration_name, step.action_name) do
      {:ok, action_def} ->
        execute_action(step, action_def, pipeline_data, context)

      {:error, :not_found} ->
        error_msg = "Action not found: #{step.integration_name}.#{step.action_name}"
        Logger.error(error_msg, step_id: step.id)

        {:error,
         %{
           step_id: step.id,
           error: error_msg,
           integration: step.integration_name,
           action: step.action_name
         }}
    end
  end

  @doc """
  Validates step input against action schema (optional validation)
  """
  def validate_input(%Step{} = step, input_data) do
    case Step.get_action_definition(step) do
      {:ok, action_def} ->
        validate_against_schema(input_data, action_def.input_schema)

      {:error, :not_found} ->
        {:error, "Action not found for validation"}
    end
  end

  # Private functions

  defp execute_action(step, action_def, pipeline_data, context) do
    # Merge step's input_map with pipeline data and context
    input_data = merge_input_data(step.input_map, pipeline_data, context)

    # Log input data for debugging
    Logger.debug("Merged input data",
      step_id: step.id,
      input_keys: Map.keys(input_data),
      static_input: step.input_map
    )

    # Extract MFA from action definition
    {module, function, base_args} = action_def.executor

    # Append input_data to the arguments list
    args = base_args ++ [input_data]

    Logger.debug(
      inspect(
        {"Invoking action executor",
         step_id: step.id, module: module, function: function, args_count: length(args)}
      )
    )

    try do
      case apply(module, function, args) do
        {:ok, result} ->
          Logger.debug(
            inspect(
              {"Step execution successful",
               step_id: step.id, result_keys: Map.keys(result || %{})}
            )
          )

          {:ok,
           %{
             step_id: step.id,
             step_name: step.name,
             step_type: step.type,
             integration: step.integration_name,
             action: step.action_name,
             output: result,
             status: :success,
             execution_time: System.monotonic_time(:millisecond)
           }}

        {:error, reason} ->
          Logger.warning(
            inspect(
              {"Step execution failed",
               step_id: step.id, step_name: step.name, reason: inspect(reason)}
            )
          )

          {:error,
           %{
             step_id: step.id,
             error: "Action execution failed: #{inspect(reason)}",
             integration: step.integration_name,
             action: step.action_name,
             input_data: sanitize_for_logging(input_data)
           }}

        other ->
          Logger.warning("Unexpected return value from step",
            step_id: step.id,
            return_value: inspect(other)
          )

          {:error,
           %{
             step_id: step.id,
             error: "Unexpected return value: #{inspect(other)}",
             integration: step.integration_name,
             action: step.action_name
           }}
      end
    rescue
      error ->
        Logger.error("Action executor crashed",
          step_id: step.id,
          error: inspect(error),
          stacktrace: Exception.format_stacktrace(__STACKTRACE__)
        )

        {:error,
         %{
           step_id: step.id,
           error: "Action executor crashed: #{inspect(error)}",
           integration: step.integration_name,
           action: step.action_name,
           crash_type: error.__struct__
         }}
    end
  end

  defp merge_input_data(input_map, pipeline_data, context) do
    # Start with step's static input_map
    base_input = input_map || %{}

    # Add pipeline data (from previous step or trigger)
    # Use both string and atom keys for flexibility
    with_pipeline_data =
      Map.merge(base_input, %{
        "pipeline_data" => pipeline_data,
        :pipeline_data => pipeline_data
      })

    # Add context data
    with_context =
      Map.merge(with_pipeline_data, %{
        "context" => context,
        :context => context
      })

    # Flatten pipeline_data into root level for easier access
    case pipeline_data do
      %{} = data when data != %{} ->
        Map.merge(with_context, data)

      _ ->
        with_context
    end
  end

  defp validate_against_schema(input_data, schema) do
    # Basic schema validation - can be enhanced with proper JSON schema library
    case schema do
      %{"required" => required_fields} ->
        missing_fields =
          Enum.reject(required_fields, fn field ->
            Map.has_key?(input_data, field) or Map.has_key?(input_data, String.to_atom(field))
          end)

        if Enum.empty?(missing_fields) do
          {:ok, input_data}
        else
          {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
        end

      _ ->
        {:ok, input_data}
    end
  end

  defp sanitize_for_logging(input_data) do
    # Remove sensitive data from logs
    sensitive_keys = ["password", "token", "secret", "key", "auth"]

    Enum.reduce(input_data, %{}, fn {k, v}, acc ->
      key_str = to_string(k) |> String.downcase()

      if Enum.any?(sensitive_keys, &String.contains?(key_str, &1)) do
        Map.put(acc, k, "[REDACTED]")
      else
        Map.put(acc, k, v)
      end
    end)
  end
end

defmodule AutomationPlatform.StepResult do
  @moduledoc """
  Helper functions for working with step execution results
  """

  @doc """
  Checks if step execution was successful
  """
  def success?(%{status: :success}), do: true
  def success?(_), do: false

  @doc """
  Gets output data from step result
  """
  def get_output(%{output: output}), do: output
  def get_output(_), do: nil

  @doc """
  Gets error information from failed step result
  """
  def get_error(%{error: error}), do: error
  def get_error(_), do: nil

  @doc """
  Extracts specific field from step output
  """
  def extract_field(%{output: output}, field) when is_map(output) do
    Map.get(output, field) || Map.get(output, to_string(field))
  end

  def extract_field(_, _), do: nil

  @doc """
  Formats step result for logging
  """
  def format_for_log(%{step_name: name, status: :success, output: output}) do
    "Step '#{name}' completed successfully. Output keys: #{inspect(Map.keys(output || %{}))}"
  end

  def format_for_log(%{step_name: name, status: status, error: error}) do
    "Step '#{name}' failed with status #{status}. Error: #{error}"
  end

  def format_for_log(result) do
    "Step result: #{inspect(result)}"
  end
end
