defmodule Pocsync.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @integrations [Pocsync.Integration.Shopee, Pocsync.Integration.Oms, Pocsync.Integration.Builtin]

  @impl true
  def start(_type, _args) do
    children = [
      Pocsync.Repo,
      {DNSCluster, query: Application.get_env(:pocsync, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pocsync.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Pocsync.Finch},
      {AutomationPlatform.IntegrationRegistry, integrations: collect_integrations()},
      Pocsync.RMQPublisher
      # Start a worker by calling: Pocsync.Worker.start_link(arg)
      # {Pocsync.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Pocsync.Supervisor)
  end

  defp collect_integrations do
    Enum.into(@integrations, %{}, fn module ->
      definition = module.definition()

      {definition.name,
       %{
         name: definition.name,
         description: definition.description,
         actions:
           Enum.into(definition.actions, %{}, fn action ->
             {action.name, action}
           end)
       }}
    end)
  end
end
