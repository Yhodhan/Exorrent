defmodule Exorrent.Listener do
  use GenServer

  def start_link(opts),
    do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    port = Keyword.get(opts, :port, 6881)

    case :gen_tcp.listen(port, [:binary, packet: :raw, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        send(self(), :accept)
        {:ok, %{listen_socket: listen_socket, port: port}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  def handle_info(:accept, %{listen_socket: listen_socket} = state) do
    case :gen_tcp.accept(listen_socket, 5_000) do
      {:ok, socket} ->
        {:ok, pid} =
          DynamicSupervisor.start_child(
            Exorrent.InboundPeerSupervisor,
            {Exorrent.InboundConnection, :inbound, socket}
          )

        :ok = :gen_tcp.controlling_process(socket, pid)
        send(self(), :accept)
        {:noreply, state}

      {:error, :timeout} ->
        send(self(), :accept)
        {:noreply, state}
    end
  end
end
