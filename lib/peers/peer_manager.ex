defmodule Exorrent.PeerManager do
  alias Exorrent.PeerConnection
  use Supervisor

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
            start: {PeerConnection, :start_link, [%{peer: peer}]}
          }
        end)

    Supervisor.init(children, strategy: :one_for_one)
  end

  def broadcast() do
    Registry.dispatch(:peer_registry, :broadcast, fn entries ->
      for {pid, _value} <- entries do
        GenServer.cast(pid, :connect)
      end
    end)
  end

  def check_peer_connection() do
    conns = []

    Registry.dispatch(:peer_registry, :broadcast, fn entries ->
      for {pid, _value} <- entries do
        conns ++ GenServer.call(pid, :peer_status)
      end
    end)

    conns
  end

  def get_peer() do
    Supervisor.which_children(__MODULE__)
  end

  def kill() do
    Supervisor.stop(__MODULE__,:normal)
  end
end
