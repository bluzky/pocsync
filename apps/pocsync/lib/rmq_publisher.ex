defmodule Pocsync.RMQPublisher do
  @moduledoc """
  The message sender

  This worker prevents connection/channel leak by centralizing
  sending messages with limited number of connections/channels

  Idea:

    In the process state, we have a value that is called channel_map
    and it stores AMQP channels with their expired time. Number of keys in
    channel_map should be lower than or equal to max_channels (currently 50).

  channel_map structure:

    %{
      "channel_id" => {amqp_channel, expired_unix_time}
    }

  Reference

    https://www.rabbitmq.com/channels.html
  """
  use GenServer

  require Logger

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, {connection, channel}} = setup_channel()
    Process.monitor(connection.pid)
    Process.monitor(channel.pid)
    {:ok, %{connection: connection, channel: channel}}
  end

  defp setup_channel do
    # connection = Application.get_env(:iris_core, :rabbitmq_url)

    connection = "amqp://localhost:5672?heartbeat=30"

    # raise error :v
    {:ok, connection} = AMQP.Connection.open(connection)

    case AMQP.Channel.open(connection) do
      {:ok, channel} ->
        {:ok, {connection, channel}}

      error ->
        AMQP.Connection.close(connection)
        Logger.error("Open AMQP channel failed: #{inspect(error)}")
        :error
    end
  end

  @doc """
  Send messages using an AMQP channel
  Accept list of map then encode and push to given queue
  """
  @spec send_messages(
          queue :: String.t(),
          messages :: list(map()),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def send_messages(queue, messages, opts \\ []) do
    # Encode messages
    encoded_messages =
      Enum.map(messages, fn message ->
        case Jason.encode(message) do
          {:ok, encoded_message} ->
            encoded_message

          err ->
            Logger.error(
              "RabbitMQHelper err = #{inspect(err)} with message = #{inspect(message)}"
            )

            nil
        end
      end)

    encoded_messages = Enum.reject(encoded_messages, &is_nil/1)
    GenServer.call(__MODULE__, {:send_messages, [queue, encoded_messages, opts]})
  rescue
    exception ->
      Sentry.capture_exception(exception, stacktrace: __STACKTRACE__)
  end

  @impl true
  def handle_call({:send_messages, [queue, messages, opts]}, _from, state) do
    exchange = opts[:exchange] || ""
    channel = state.channel

    Enum.each(messages, fn message ->
      AMQP.Basic.publish(channel, exchange, queue, message)
    end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_info({:DOWN, _, :process, pid, reason}, state) do
    Logger.error("AMQP process #{inspect(pid)} died: #{inspect(reason)}")

    cond do
      pid == state.connection.pid ->
        case setup_channel() do
          {:ok, {connection, channel}} ->
            Process.monitor(connection.pid)
            Process.monitor(channel.pid)
            {:noreply, %{connection: connection, channel: channel}}

          _ ->
            {:stop, "Open AMQP connection failed"}
        end

      pid == state.channel.pid ->
        case AMQP.Channel.open(state.connection) do
          {:ok, channel} ->
            Process.monitor(channel.pid)
            {:noreply, Map.put(state, :channel, channel)}

          error ->
            Logger.error("Open AMQP channel again failed: #{inspect(error)}")
            {:stop, "Open AMQP channel failed"}
        end

      true ->
        {:stop, "Unkown error"}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end
end
