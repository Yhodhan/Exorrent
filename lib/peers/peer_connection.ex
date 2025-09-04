defmodule Exorrent.PeerConnection do
  alias Exorrent.Peer
  alias Exorrent.TorrentParser

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

  def send_handshake(pid, msg),
    do: GenServer.cast(pid, {:send_tcp, msg})

  def tcp_response(pid),
    do: GenServer.call(pid, :tcp_response)

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

    case :gen_tcp.connect(ip, port, [:binary, packet: :raw, active: false]) do
      {:ok, socket} ->
        Logger.info("=== Succesfull connection #{inspect(ip)}:#{port}")

        {:noreply, update_state(state, :connected, socket)}

      {:error, reason} ->
        Logger.error("=== Failed to connect #{inspect(ip)}:#{port} reason=#{inspect(reason)}")
        #        Logger.flush()
        {:noreply, update_state(state, :not_connected, nil)}
    end
  end

  def handle_cast({:send_tcp, msg}, state) do
    %Peer{socket: socket} = state

    Logger.info("=== Sending msg to socket: #{inspect(socket)}")

    :gen_tcp.send(socket, msg)

    {:noreply, state}
  end

  def handle_call(:tcp_response, _from, state) do
    Logger.debug("Reading data from socket: #{inspect(state.socket)}")

    case :gen_tcp.recv(state.socket, 68) do
      {:ok, data} ->
        # parse_msg(data)
        {:reply, data, state}

      {:error, reason} ->
        Logger.error(
          "Failed to receive msg in socket: #{inspect(state.socket)} reason:#{inspect(reason)}"
        )

        {:reply, :failed, state}
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

  # --------------------
  #     Connection
  # --------------------

  def build_handshake(torrent) do
    pstr = "BitTorrent protocol"
    pstrlen = byte_size(pstr)
    reserved = <<0::64>>
    info_hash = TorrentParser.get_info_hash(torrent)
    peer_id = "-EX0001-" <> :crypto.strong_rand_bytes(12)

    <<pstrlen::8, pstr::binary, reserved::binary, info_hash::binary-size(20), peer_id::binary>>
  end
end
