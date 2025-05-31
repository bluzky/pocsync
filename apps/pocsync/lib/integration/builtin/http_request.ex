defmodule Pocsync.Builtin.HttpRequest do
  @moduledoc """
  HTTP integration providing GET, POST, and webhook trigger actions
  """

  require Logger

  def definition do
    [
      %{
        name: "pocsync.http.request",
        description: "Send HTTP request to external endpoint",
        input_schema: %{},
        output_schema: %{},
        executor: {__MODULE__, :request, []}
      },
      %{
        name: "pocsync.http.webhook_trigger",
        description: "Receive and process webhook data",
        executor: {__MODULE__, :webhook_trigger, []},
        input_schema: %{
          "type" => "object",
          "properties" => %{
            "body" => %{"type" => "object", "description" => "Webhook body"},
            "headers" => %{"type" => "object", "description" => "Webhook headers"},
            "query_params" => %{"type" => "object", "description" => "Query parameters"}
          }
        },
        output_schema: %{
          "type" => "object",
          "properties" => %{
            "data" => %{"type" => "object"},
            "timestamp" => %{"type" => "string"},
            "trigger_type" => %{"type" => "string"}
          }
        }
      }
    ]
  end

  def request(input_data) do
    method = input_data["method"] || input_data[:method] || "GET"
    input_data = Map.delete(input_data, "method")
    url = input_data["url"]

    headers = Map.get(input_data, "headers", %{})
    query = Map.get(input_data, "query", %{})
    payload = Map.get(input_data, "payload", %{})

    Logger.info("Making HTTP #{method} request", url: url)

    # Build the request options
    options = build_request_options(method, headers, query, payload)

    # Make the request
    Req.request([method: method, url: url] ++ options)
    |> handle_response()
  rescue
    error ->
      {:error, error}
  end

  # Private function to build request options
  defp build_request_options(method, headers, query, body) do
    options = []

    # Add headers if provided
    options = if map_size(headers) > 0, do: [headers: headers] ++ options, else: options

    # Add query parameters if provided
    options = if map_size(query) > 0, do: [params: query] ++ options, else: options

    # Add body if provided (for methods that support it)
    options =
      if body && method_supports_body?(method) do
        [body: body] ++ options
      else
        options
      end

    options
  end

  # Check if HTTP method supports request body
  defp method_supports_body?(method) when method in [:post, :put, :patch, :delete], do: true
  defp method_supports_body?(_), do: false

  defp handle_response({:ok, response}) do
    Logger.info("HTTP request successful", status: response.status)

    {:ok,
     %{
       "status" => response.status,
       "headers" => response.headers,
       "body" => response.body
     }}
  end

  defp handle_response({:error, reason}) do
    Logger.error("HTTP request failed", reason: inspect(reason))

    {:error,
     %{
       "error" => reason
     }}
  end

  @doc """
  Processes webhook trigger data
  """
  def webhook_trigger(input_data) do
    Logger.info("Processing webhook trigger",
      data_keys: Map.keys(input_data || %{})
    )

    # Extract webhook data from various possible input formats
    webhook_data =
      case input_data do
        %{body: body, headers: headers} ->
          %{body: body, headers: headers}

        %{"body" => body, "headers" => headers} ->
          %{body: body, headers: headers}

        data when is_map(data) ->
          data

        _ ->
          %{}
      end

    {:ok,
     %{
       data: webhook_data,
       timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
       trigger_type: "webhook",
       processed_at: DateTime.utc_now()
     }}
  end
end
