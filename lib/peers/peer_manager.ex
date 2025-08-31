defmodule Exorrent.PeerManager do
  alias Exorrent.PeerConnection
  use Supervisor
  require Logger

  def start_link(peers) do
    Supervisor.start_link(__MODULE__, peers, name: __MODULE__)
  end

  @impl true
  def init(peers) do
    children =
      [
        {Registry, keys: :unique, name: :peer_registry}
      ] ++
        Enum.map(peers, fn peer ->
          %{
            id: {:peer, peer},
            start: {PeerConnection, :start_link, [%{peer: peer}]},
          }
        end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def broadcast() do
    Logger.info("=== Init broadcast ===")

    peers = Registry.select(:peer_registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])

    Enum.each(peers, fn {_key, pid} ->
      GenServer.cast(pid, :connect)
    end)

    Logger.info("=== Finish broadcast ===")
  end

  def check_peer_connection() do
    conns = []

    peers = Registry.select(:peer_registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])

    Enum.each(peers, fn {_key, pid} ->
      conn_status = GenServer.call(pid, :peer_status)
      conns ++ [conn_status]
    end)

    conns
  end

  def get_peer() do
    Supervisor.which_children(__MODULE__)
  end

  def kill() do
    Supervisor.stop(__MODULE__, :normal)
  end
end
