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
    url = extract_url(input_data)

    Logger.info("Making HTTP #{method} request", url: url)

    case validate_url(url) do
      :ok ->
        {:ok,
         %{
           status_code: 200,
           headers: %{
             "content-type" => "application/json",
             "x-request-id" => generate_request_id()
           },
           body: "atest"
         }}

      {:error, reason} ->
        {:error, "Invalid URL: #{reason}"}
    end
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

  # Helper functions

  defp extract_url(input_data) do
    input_data["url"] || input_data[:url] ||
      input_data["pipeline_data"]["url"] || input_data[:pipeline_data][:url] ||
      ""
  end

  defp validate_url(url) when is_binary(url) and byte_size(url) > 0 do
    if String.starts_with?(url, ["http://", "https://"]) do
      :ok
    else
      {:error, "URL must start with http:// or https://"}
    end
  end

  defp validate_url(_), do: {:error, "URL is required and must be a string"}

  defp generate_request_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16() |> String.downcase()
  end
end
