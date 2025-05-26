# User defines their own pipeline configuration
config = %{
  name: "Custom User Pipeline",
  description: "User-defined automation workflow",
  steps: [
    %{
      name: "My Webhook Receiver",
      type: :trigger,
      integration_name: "pocsync.builtin",
      action_name: "pocsync.http.webhook_trigger",
      input_map: %{}
    },
    %{
      name: "Transform User Data",
      type: :action,
      integration_name: "pocsync.builtin",
      action_name: "pocsync.transform.map_fields",
      input_map: %{
        mapping: %{"user_id" => "id", "user_name" => "name"}
      }
    },
    %{
      name: "Send to CRM",
      type: :action,
      integration_name: "pocsync.builtin",
      action_name: "pocsync.http.request",
      input_map: %{
        url: "https://my-crm.com/api/users",
        headers: %{"Authorization" => "Bearer my-token"}
      }
    },
    %{
      name: "Log Success",
      type: :output,
      integration_name: "pocsync.builtin",
      action_name: "pocsync.log",
      input_map: %{message: "User synced to CRM"}
    }
  ]
}

alias Pocsync.PipelineBuilder
alias AutomationPlatform.PipelineExecutor

# Build and execute
{:ok, validated_config} = PipelineBuilder.validate_config(config)
pipeline = PipelineBuilder.from_config(validated_config)

message = %{
  pipeline: pipeline,
  context: %{user_id: 123, user_name: "John Doe"}
}

# Pocsync.RMQPublisher.send_messages("inn_pipeline_queue", [message])
# result = PipelineExecutor.execute(pipeline, %{user_id: 123, user_name: "John Doe"})

# IO.inspect(result, label: "Pipeline Execution Result")
