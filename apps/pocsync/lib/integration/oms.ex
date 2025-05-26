defmodule Pocsync.Integration.Oms do
  @moduledoc """
  Integration for OMS App
  """

  @actions [
    Pocsync.Oms.Action.CreateOrder,
    Pocsync.Oms.Action.UpdateOrder
  ]

  def definition do
    %{
      name: integration_name(),
      description: integration_description(),
      actions: Enum.map(@actions, & &1.definition())
    }
  end

  def integration_name, do: "oms_app"

  def integration_description, do: "Integration for OMS App"
end
