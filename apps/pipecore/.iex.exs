# Start the system
{:ok, _} = AutomationPlatform.IntegrationRegistry.start_link()

# Create and execute a pipeline
pipeline =
  AutomationPlatform.PipelineBuilder.webhook_to_api_pipeline(
    "User Sync",
    "https://api.example.com/users"
  )

webhook_data = %{body: %{user_id: 123}, headers: %{}}
result = AutomationPlatform.PipelineExecutor.execute(pipeline, webhook_data)

# Check results
if AutomationPlatform.ExecutionResult.success?(result) do
  IO.inspect(AutomationPlatform.ExecutionResult.summary(result))
end
