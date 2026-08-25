defmodule Peers.PeerConnection do
  alias Peers.Worker
  alias Peers.Messages

  require Logger

  @pstr "BitTorrent protocol"

  # -----------------------
  #  Outbound connections
  # -----------------------

  def peer_connect(peer) do
    {ip, port} = peer

    case :gen_tcp.connect(ip, port, [:binary, packet: :raw, active: false], 2000) do
      {:ok, socket} ->
        Logger.info("=== Succesfull connection #{inspect(ip)}:#{port} ===")
        {:ok, socket}

      {:error, reason} ->
        Logger.error("=== Failed to connect #{inspect(ip)}:#{port} reason=#{inspect(reason)} ===")
        {:error, reason}
    end
  end

  def send_handshake(socket, msg) do
    Logger.info("=== Sending msg to socket: #{inspect(socket)} ===")

    :gen_tcp.send(socket, msg)
  end

  def handshake_response(socket, info_hash) do
    Logger.info("=== Reading data from socket: #{inspect(socket)} ===")

    with {:ok, <<len::8>>} <- :gen_tcp.recv(socket, 1),
         {:ok, pstr} <- :gen_tcp.recv(socket, len),
         {:ok, _reserved} <- :gen_tcp.recv(socket, 8),
         {:ok, hash} <- :gen_tcp.recv(socket, 20) do
      case {pstr, hash} do
        {@pstr, ^info_hash} -> :ok
        _ -> :error
      end
    end
  end

  def complete_handshake(socket, torrent) do
    Logger.info("=== Completing handshake ===")

    case :gen_tcp.recv(socket, 20) do
      {:ok, peer_id} ->
        peer_state = peer_state(socket, peer_id, torrent)

        {:ok, worker_pid} = Worker.start_link(peer_state)
        :gen_tcp.controlling_process(socket, worker_pid)

        {:ok, worker_pid}

      _ ->
        :error
    end
  end

  def terminate_connection(socket) do
    Logger.info("=== Terminating connection to socket: #{inspect(socket)} ===")
    :gen_tcp.close(socket)
  end

  # -----------------------
  #  inbound connections
  # -----------------------

  def read_handshake(socket) do
    with {:ok, <<len::8>>} <- :gen_tcp.recv(socket, 1),
         {:ok, pstr} <- :gen_tcp.recv(socket, len),
         {:ok, _reserved} <- :gen_tcp.recv(socket, 8),
         {:ok, info_hash} <- :gen_tcp.recv(socket, 20) do
      case pstr do
        @pstr -> {:ok, info_hash}
        _ -> :error
      end
    end
  end

  def send_handshake_reply(socket, info_hash) do
    msg = Messages.build_handshake(info_hash)
    send_handshake(socket, msg)
  end

  # ---------------------
  #       Helper
  # ---------------------

  # for the Worker GenServer
  defp peer_state(socket, peer_id, torrent) do
    %{
      socket: socket,
      info_hash: torrent.info_hash,
      size: torrent.size,
      peer_id: peer_id,
      status: :idle,
      choke: true,
      unchoked: false,
      interested: false,
      has_bitfield?: false,
      total_pieces: torrent.total_pieces,
      piece_length: torrent.piece_length,
      requested: nil,
      pieces_list: torrent.pieces_list,
      bitfield: %{}
    }
  end
end
