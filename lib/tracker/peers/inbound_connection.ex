defmodule Exorrent.InboundConnection do
  use Task
  require Logger
  alias Peers.PeerConnection

  def start_link(socket) do
    Task.start_link(fn -> run(socket) end)
  end

  def run(socket) do
    with {:ok, info_hash} <- PeerConnection.read_handshake(socket),
         [{_session_pid, torrent}] <-
           Registry.lookup(Exorrent.TorrentRegistry, {:session, info_hash}),
         :ok <- PeerConnection.send_handshake_reply(socket, info_hash),
         {:ok, _pid} <- PeerConnection.complete_handshake(socket, torrent) do
      :ok
    else
      error ->
        Logger.error("=== Inbound handshake failed: #{inspect(error)} ====")
        :gen_tcp.close(socket)
    end
  end
end
