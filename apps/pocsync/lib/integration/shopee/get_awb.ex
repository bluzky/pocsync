defmodule Pocsync.Shopee.Action.GetAWB do
  @moduledoc """
  Action to get the AWB (Air Waybill) number for a Shopee order.
  """

  def definition() do
    %{
      name: "get_awb",
      description: "Get the AWB number for a Shopee order",
      input_schema: %{},
      output_schema: %{},
      executor: {__MODULE__, :call, []}
    }
  end

  def call(_input_data, _context) do
    # Simulate fetching the AWB number logic
    {:ok, %{awb_number: "AWB123456789"}}
  end
end
