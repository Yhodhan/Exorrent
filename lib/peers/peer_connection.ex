defmodule Exorrent.PeerConnection do
  alias Exorrent.Peer

  use GenServer
  require Logger

  @pstr "BitTorrent Protocol"

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

  def complete_handshake(pid),
    do: GenServer.call(pid, :handshake_response, 15000)

  def terminate_connection(pid),
    do: GenServer.cast(pid, :terminate)

  # ----------------------
  #   GenServer functions
  # ----------------------
  def init(peer) do
    Registry.register(:peer_registry, {:peer, peer.ip, peer.port}, peer)
    {:ok, peer}
  end

  def handle_cast(:terminate, state) do
    :gen_tcp.close(state.socket)
    {:stop, :normal, state}
  end

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

  def handle_call(:handshake_response, _from, state) do
    Logger.debug("Reading data from socket: #{inspect(state.socket)}")
    socket = state.socket

    with {:ok, <<len::8>>} <- :gen_tcp.recv(socket, 1),
         {:ok, pstr} <- :gen_tcp.recv(socket, len),
         {:ok, _reserved} <- :gen_tcp.recv(socket, 8),
         {:ok, info_hash} <- :gen_tcp.recv(socket, 20) do
      case pstr do
        @pstr -> {:reply, info_hash, state}
        _ -> {:reply, :error, state}
      end
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
    pstrlen = byte_size(@pstr)
    reserved = <<0::64>>
    info_hash = torrent.info_hash
    peer_id = "-EX0001-" <> :crypto.strong_rand_bytes(12)

    <<pstrlen::8, @pstr::binary, reserved::binary, info_hash::binary-size(20), peer_id::binary>>
  end

  def parse_tcp_response(msg) do
    case msg do
      <<0::32, _id::8, _>> ->
        :keep_alive

      <<1::32, 0::8, _>> ->
        :choke

      <<0::32, 1::8, _>> ->
        :unchoke

      <<1::32, 2::8, _>> ->
        :interested

      <<1::32, 3::8, _>> ->
        :not_interested
    end
  end
end
