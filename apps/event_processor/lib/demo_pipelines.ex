defmodule DemoPipelines do
  alias Pocsync.PipelineBuilder

  def all do
    [
      shopee_create_order_pipeline(),
      shopee_confim_pack_pipeline()
    ]
  end

  def shopee_create_order_pipeline() do
    config = %{
      name: "Shopee create order pipeline",
      description: "User-defined automation workflow",
      pattern: %{},
      steps: [
        %{
          name: "Order created Webhook Receiver",
          type: :trigger,
          integration_name: "pocsync.builtin",
          action_name: "pocsync.http.webhook_trigger",
          input_map: %{}
        },
        %{
          name: "Transform order Data",
          type: :action,
          integration_name: "pocsync.builtin",
          action_name: "pocsync.transform.map_fields",
          input_map: %{
            mapping: %{"user_id" => "id", "user_name" => "name"}
          }
        },
        %{
          name: "Send to OMS",
          type: :action,
          integration_name: "pocsync.builtin",
          action_name: "pocsync.http.request",
          input_map: %{
            url: "https://my-crm.com/api/users",
            headers: %{"Authorization" => "Bearer my-token"}
          }
        }
      ]
    }

    {:ok, validated_config} = PipelineBuilder.validate_config(config)
    pipeline = PipelineBuilder.from_config(validated_config)
  end

  def shopee_confim_pack_pipeline() do
    config = %{
      name: "Shopee confirm pack order pipeline",
      description: "Shopee confirm pack order pipeline",
      pattern: %{},
      steps: [
        %{
          name: "Order confirm packed Webhook Receiver",
          type: :trigger,
          integration_name: "pocsync.builtin",
          action_name: "pocsync.http.webhook_trigger",
          input_map: %{}
        },
        %{
          name: "Transform to shopee params",
          type: :action,
          integration_name: "pocsync.builtin",
          action_name: "pocsync.transform.map_fields",
          input_map: %{
            mapping: %{"user_id" => "id", "user_name" => "name"}
          }
        },
        %{
          name: "Send to Shopee API",
          type: :action,
          integration_name: "pocsync.builtin",
          action_name: "pocsync.http.request",
          input_map: %{
            url: "https://my-crm.com/api/users",
            headers: %{"Authorization" => "Bearer my-token"}
          }
        }
      ]
    }

    {:ok, validated_config} = PipelineBuilder.validate_config(config)
    pipeline = PipelineBuilder.from_config(validated_config)
  end
end
