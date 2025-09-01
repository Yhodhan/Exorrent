defmodule Exorrent.PeerConnection do
  alias Exorrent.Peer

  use GenServer
  require Logger

  # -------------------
  #   GenServer calls
  # -------------------

  # initial states:
  #  %Peer{ip, port, status, socket}
  def start_link(%Peer{} = peer),
    do: GenServer.start_link(__MODULE__, peer)

  def peer_connect(pid),
    do: GenServer.cast(pid, :connect)

  def peer_health(pid),
    do: GenServer.call(pid, :status)

  # ----------------------
  #   GenServer functions
  # ----------------------
  def init(peer) do
    Registry.register(:peer_registry, {:peer, peer.ip, peer.port}, peer)
    {:ok, peer}
  end

  def handle_cast(:terminate, state),
    do: {:stop, :normal, state}

  def handle_cast(:connect, state) do
    %Peer{ip: ip, port: port} = state

    case :gen_tcp.connect(ip, port, [:binary, {:active, false}]) do
      {:ok, socket} ->
        Logger.debug("=== Succesfull connection #{inspect(ip)}:#{port}")

        {:noreply, update_state(state, :connected, socket)}

      {:error, reason} ->
        Logger.debug("=== Failed to connect #{inspect(ip)}:#{port} reason=#{inspect(reason)}")
        #        Logger.flush()
        {:noreply, update_state(state, :not_connected, nil)}
    end
  end

  def handle_call(:peer_status, _from, state),
    do: {:reply, state, state}

  # ---------------------
  #     Name helper
  # ---------------------

  defp update_state(state, conn, socket) do
    peer = state
    %{peer | status: conn, socket: socket, pid: self()}
  end
end
