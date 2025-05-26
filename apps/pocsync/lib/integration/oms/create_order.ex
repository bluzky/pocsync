defmodule Pocsync.Oms.Action.CreateOrder do
  def definition() do
    %{
      name: "create_order",
      description: "Create a new order in the OMS",
      input_schema: %{},
      output_schema: %{},
      executor: {__MODULE__, :call, []}
    }
  end

  def call(_input_data, _context) do
    # Simulate order creation logic
    {:ok, %{order_id: "12345", status: "created"}}
  end
end
