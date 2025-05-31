defmodule PocsyncWeb.WebhookController do
  use PocsyncWeb, :controller

  @doc """
  Handles incoming webhooks by delegating to the WebhookHandler.
  """
  def handle(conn, params) do
    event = %{
      source: "webhook",
      path: conn.request_path,
      method: conn.method,
      params: params,
      headers: Map.new(conn.req_headers)
    }

    Pocsync.RMQPublisher.send_messages("inn_event_queue", [event])

    conn
    |> put_status(200)
    |> json(%{message: "Event received and processed"})
  end
end
