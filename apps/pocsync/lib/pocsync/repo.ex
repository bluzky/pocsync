defmodule Pocsync.Repo do
  use Ecto.Repo,
    otp_app: :pocsync,
    adapter: Ecto.Adapters.Postgres
end
