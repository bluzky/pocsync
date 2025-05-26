defmodule Pocsync.Shopee.Action.ReadyToShip do
  @moduledoc """
  Action to mark an order as ready to ship in Shopee.
  """

  def definition() do
    %{
      name: "ready_to_ship",
      description: "Mark an order as ready to ship in Shopee",
      input_schema: %{},
      output_schema: %{},
      executor: {__MODULE__, :call, []}
    }
  end

  def call(_input_data, _context) do
    # Simulate marking an order as ready to ship
    {:ok, %{order_id: "12345", status: "ready_to_ship"}}
  end
end
