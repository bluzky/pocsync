defmodule Pocsync.Integration.Builtin do
  @moduledoc """
  Integration for Shopee
  """

  @actions [
    Pocsync.Builtin.HttpRequest,
    Pocsync.Builtin.Log,
    Pocsync.Builtin.Transform
  ]

  def definition do
    %{
      name: integration_name(),
      description: integration_description(),
      actions: Enum.map(@actions, & &1.definition()) |> List.flatten()
    }
  end

  def integration_name, do: "pocsync.builtin"

  def integration_description, do: "Built in support actions"
end
