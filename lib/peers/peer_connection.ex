defmodule Peers.PeerConnection do
  alias Exorrent.Peer
  alias Peers.Worker

  require Logger

  @pstr "BitTorrent protocol"

  def peer_connect(torrent, peer) do
    {ip, port} = peer

    case :gen_tcp.connect(ip, port, [:binary, packet: :raw, active: false]) do
      {:ok, socket} ->
        Logger.info("=== Succesfull connection #{inspect(ip)}:#{port}")

        {:ok, update_peer(torrent, socket)}

      {:error, reason} ->
        Logger.error("=== Failed to connect #{inspect(ip)}:#{port} reason=#{inspect(reason)}")
        {:error, reason}
    end
  end

  def send_handshake(peer, msg) do
    %Peer{socket: socket} = peer

    Logger.info("=== Sending msg to socket: #{inspect(socket)}")

    :gen_tcp.send(socket, msg)
  end

  def handshake_response(peer) do
    Logger.info("Reading data from socket: #{inspect(peer.socket)}")
    %Peer{socket: socket, info_hash: info_hash} = peer

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

  def complete_handshake(peer) do
    Logger.info("=== Completing handshake")
    %Peer{socket: socket} = peer

    case :gen_tcp.recv(socket, 20) do
      {:ok, peer_id} ->
        peer_state = peer_state(peer, peer_id)

        {:ok, worker_pid} = Worker.start_link(peer_state)
        :gen_tcp.controlling_process(socket, worker_pid)

        {:ok, worker_pid}

      _ ->
        :error
    end
  end

  def terminate_connection(peer) do
    Logger.info("=== Terminating connection to socket: #{peer.socket}")
    :gen_tcp.close(peer.socket)
  end

  # ---------------------
  #       Helper
  # ---------------------

  defp update_peer(torrent, socket) do
    %Peer{
      socket: socket,
      info_hash: torrent.info_hash,
      size: torrent.size
    }
  end

  defp peer_state(peer, peer_id) do
    %{
      socket: peer.socket,
      info_hash: peer.info_hash,
      size: peer.size,
      peer_id: peer_id,
      status: :idle,
      choke: true,
      unchoked: false,
      interested: false,
      bitfield: %MapSet{}
    }
  end
end
