defmodule Pocsync.Integration.Shopee do
  @moduledoc """
  Integration for Shopee
  """

  @actions [
    Pocsync.Shopee.Action.ReadyToShip,
    Pocsync.Shopee.Action.GetAWB
  ]

  def definition do
    %{
      name: integration_name(),
      description: integration_description(),
      actions: Enum.map(@actions, & &1.definition())
    }
  end

  def integration_name, do: "shopee"

  def integration_description, do: "Integration for Shopee"
end
