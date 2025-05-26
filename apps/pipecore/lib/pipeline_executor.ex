defmodule AutomationPlatform.PipelineExecutor do
  @moduledoc """
  Executes pipelines step by step, managing data flow and error handling
  """

  require Logger
  alias AutomationPlatform.{Pipeline, Step, StepExecutor}

  defstruct [
    :pipeline,
    :execution_id,
    :context,
    :results,
    :status,
    :started_at,
    :completed_at,
    :error
  ]

  @type execution_status :: :pending | :running | :success | :failed | :cancelled

  @type t :: %__MODULE__{
          pipeline: Pipeline.t(),
          execution_id: String.t(),
          context: map(),
          results: [map()],
          status: execution_status(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          error: String.t() | nil
        }

  @doc """
  Executes a pipeline with optional initial context
  """
  def execute(%Pipeline{} = pipeline, initial_context \\ %{}) do
    execution_id = generate_execution_id()

    executor = %__MODULE__{
      pipeline: pipeline,
      execution_id: execution_id,
      context: initial_context,
      results: [],
      status: :pending,
      started_at: nil,
      completed_at: nil,
      error: nil
    }

    Logger.info("Starting pipeline execution",
      pipeline_id: pipeline.id,
      pipeline_name: pipeline.name,
      execution_id: execution_id,
      steps_count: length(pipeline.steps)
    )

    executor
    |> start_execution()
    |> validate_pipeline()
    |> execute_steps()
    |> complete_execution()
  end

  @doc """
  Executes a single step with given input data (for testing)
  """
  def execute_step(%Step{} = step, input_data, context \\ %{}) do
    StepExecutor.execute(step, input_data, context)
  end

  @doc """
  Cancels a running pipeline execution
  """
  def cancel(%__MODULE__{status: :running} = executor) do
    Logger.info("Cancelling pipeline execution", execution_id: executor.execution_id)

    %{
      executor
      | status: :cancelled,
        completed_at: DateTime.utc_now(),
        error: "Execution cancelled by user"
    }
  end

  def cancel(executor), do: executor

  # Private functions

  defp start_execution(executor) do
    %{executor | status: :running, started_at: DateTime.utc_now()}
  end

  defp validate_pipeline(%{pipeline: pipeline} = executor) do
    if Pipeline.valid?(pipeline) do
      Logger.debug("Pipeline validation passed", execution_id: executor.execution_id)
      executor
    else
      Logger.error("Pipeline validation failed",
        execution_id: executor.execution_id,
        pipeline_id: pipeline.id
      )

      %{
        executor
        | status: :failed,
          error: "Pipeline validation failed",
          completed_at: DateTime.utc_now()
      }
    end
  end

  defp execute_steps(%{status: :failed} = executor), do: executor

  defp execute_steps(%{pipeline: %{steps: steps}} = executor) do
    sorted_steps = Enum.sort_by(steps, & &1.position)

    Logger.debug("Executing #{length(sorted_steps)} steps",
      execution_id: executor.execution_id
    )

    Enum.reduce_while(sorted_steps, executor, fn step, acc ->
      case execute_single_step(step, acc) do
        {:ok, updated_executor} -> {:cont, updated_executor}
        {:error, failed_executor} -> {:halt, failed_executor}
      end
    end)
  end

  defp execute_single_step(step, executor) do
    pipeline_data = build_step_input(step, executor)

    Logger.debug("Executing step",
      execution_id: executor.execution_id,
      step_id: step.id,
      step_name: step.name,
      step_position: step.position
    )

    step_start_time = System.monotonic_time(:millisecond)

    case StepExecutor.execute(step, pipeline_data, executor.context) do
      {:ok, result} ->
        step_duration = System.monotonic_time(:millisecond) - step_start_time

        enhanced_result =
          Map.merge(result, %{
            duration_ms: step_duration,
            executed_at: DateTime.utc_now()
          })

        updated_executor = %{
          executor
          | results: executor.results ++ [enhanced_result],
            context: merge_context(executor.context, result)
        }

        Logger.debug("Step completed successfully",
          execution_id: executor.execution_id,
          step_id: step.id,
          duration_ms: step_duration
        )

        {:ok, updated_executor}

      {:error, error} ->
        step_duration = System.monotonic_time(:millisecond) - step_start_time

        enhanced_error =
          Map.merge(error, %{
            duration_ms: step_duration,
            failed_at: DateTime.utc_now()
          })

        failed_executor = %{
          executor
          | status: :failed,
            error: error[:error] || "Unknown step error",
            completed_at: DateTime.utc_now(),
            results: executor.results ++ [enhanced_error]
        }

        Logger.error("Step failed",
          execution_id: executor.execution_id,
          step_id: step.id,
          error: error[:error],
          duration_ms: step_duration
        )

        {:error, failed_executor}
    end
  end

  defp build_step_input(%Step{position: 0}, %{context: context}) do
    # First step gets initial context/trigger data
    context
  end

  defp build_step_input(%Step{position: position}, %{results: results}) when position > 0 do
    # Subsequent steps get output from previous step
    case Enum.at(results, position - 1) do
      nil ->
        Logger.warning("No previous step result found", step_position: position)
        %{}

      %{output: output} when is_map(output) ->
        output

      previous_result ->
        Logger.warning("Previous step had no output",
          step_position: position,
          previous_result: inspect(previous_result)
        )

        %{}
    end
  end

  defp merge_context(current_context, step_result) do
    # Extract any context data from step result
    step_context =
      case step_result do
        %{output: %{context: ctx}} when is_map(ctx) -> ctx
        %{context: ctx} when is_map(ctx) -> ctx
        _ -> %{}
      end

    Map.merge(current_context, step_context)
  end

  defp complete_execution(%{status: :running} = executor) do
    duration = DateTime.diff(DateTime.utc_now(), executor.started_at, :millisecond)

    Logger.info("Pipeline execution completed successfully",
      execution_id: executor.execution_id,
      pipeline_id: executor.pipeline.id,
      duration_ms: duration,
      steps_executed: length(executor.results)
    )

    %{executor | status: :success, completed_at: DateTime.utc_now()}
  end

  defp complete_execution(executor) do
    # Already completed (likely failed or cancelled)
    if executor.completed_at do
      duration =
        DateTime.diff(
          executor.completed_at,
          executor.started_at || DateTime.utc_now(),
          :millisecond
        )

      Logger.info("Pipeline execution finished",
        execution_id: executor.execution_id,
        status: executor.status,
        duration_ms: duration
      )
    end

    executor
  end

  defp generate_execution_id do
    :crypto.strong_rand_bytes(16) |> Base.encode64() |> binary_part(0, 16)
  end
end

defmodule AutomationPlatform.ExecutionResult do
  @moduledoc """
  Helper functions for working with pipeline execution results
  """

  alias AutomationPlatform.PipelineExecutor

  @doc """
  Checks if execution was successful
  """
  def success?(%PipelineExecutor{status: :success}), do: true
  def success?(_), do: false

  @doc """
  Checks if execution failed
  """
  def failed?(%PipelineExecutor{status: :failed}), do: true
  def failed?(_), do: false

  @doc """
  Checks if execution was cancelled
  """
  def cancelled?(%PipelineExecutor{status: :cancelled}), do: true
  def cancelled?(_), do: false

  @doc """
  Gets execution duration in milliseconds
  """
  def duration(%PipelineExecutor{started_at: nil}), do: nil

  def duration(%PipelineExecutor{started_at: started, completed_at: nil}) do
    DateTime.diff(DateTime.utc_now(), started, :millisecond)
  end

  def duration(%PipelineExecutor{started_at: started, completed_at: completed}) do
    DateTime.diff(completed, started, :millisecond)
  end

  @doc """
  Gets final output from the last successful step
  """
  def final_output(%PipelineExecutor{results: []}), do: nil

  def final_output(%PipelineExecutor{results: results}) do
    results
    |> Enum.reverse()
    |> Enum.find_value(fn result ->
      case result do
        %{status: :success, output: output} -> output
        _ -> nil
      end
    end)
  end

  @doc """
  Gets all step outputs (successful steps only)
  """
  def all_outputs(%PipelineExecutor{results: results}) do
    results
    |> Enum.filter(&(&1[:status] == :success))
    |> Enum.map(& &1[:output])
  end

  @doc """
  Gets all step results (including failures)
  """
  def all_results(%PipelineExecutor{results: results}), do: results

  @doc """
  Gets failed steps
  """
  def failed_steps(%PipelineExecutor{results: results}) do
    Enum.filter(results, &Map.has_key?(&1, :error))
  end

  @doc """
  Formats execution summary for logging/debugging
  """
  def summary(%PipelineExecutor{} = executor) do
    successful_steps = Enum.count(executor.results, &(&1[:status] == :success))
    failed_steps = Enum.count(executor.results, &Map.has_key?(&1, :error))

    %{
      execution_id: executor.execution_id,
      pipeline_id: executor.pipeline.id,
      pipeline_name: executor.pipeline.name,
      status: executor.status,
      steps_executed: length(executor.results),
      successful_steps: successful_steps,
      failed_steps: failed_steps,
      total_steps: length(executor.pipeline.steps),
      duration_ms: duration(executor),
      error: executor.error,
      started_at: executor.started_at,
      completed_at: executor.completed_at,
      final_output: final_output(executor)
    }
  end

  @doc """
  Exports execution results to a map for external storage/analysis
  """
  def export(%PipelineExecutor{} = executor) do
    %{
      execution: summary(executor),
      step_results: all_results(executor),
      context: executor.context
    }
  end
end
