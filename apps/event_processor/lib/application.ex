defmodule EventProcessor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EventProcessor.PipelineConsumer
      # Start a worker by calling: Pocsync.Worker.start_link(arg)
      # {Pocsync.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: EventProcessor.Supervisor)
  end
end
