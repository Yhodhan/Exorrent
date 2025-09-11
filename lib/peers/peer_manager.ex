defmodule Peers.PeerManager do
#  alias Exorrent.PeerConnection
#  alias Exorrent.Peer
#  use Supervisor
#  require Logger
#
#  def start_link(peers) do
#    Supervisor.start_link(__MODULE__, peers, name: __MODULE__)
#  end
#
#  @impl true
#  def init(peers) do
#    children =
#      [
#        {Registry, keys: :unique, name: :peer_registry}
#      ] ++
#        Enum.map(peers, fn p ->
#          {ip, port} = p
#          peer = %Peer{ip: ip, port: port}
#
#          %{
#            id: {:peer, peer},
#            start: {PeerConnection, :start_link, [peer]}
#          }
#        end)
#
#    Supervisor.init(children, strategy: :one_for_one)
#  end
#
#  def broadcast() do
#    Logger.info("=== Init broadcast ===")
#
#    get_registry()
#    |> Enum.each(fn {_key, pid} ->
#      GenServer.cast(pid, :connect)
#    end)
#
#    Logger.info("=== Finish broadcast ===")
#  end
#
#  def check_peers_connections() do
#    get_registry()
#    |> Enum.map(fn {_key, pid} ->
#      GenServer.call(pid, :peer_status)
#    end)
#  end
#
#  def get_connected_peers() do
#    check_peers_connections()
#    |> Enum.filter(fn peer -> peer.status == :connected end)
#  end
#
#  def terminate_unconnected_peers() do
#    get_registry()
#    |> Enum.each(fn {_key, pid} ->
#      status = GenServer.call(pid, :peer_status)
#
#      if status === :not_connected do
#        Supervisor.delete_child(__MODULE__, pid)
#        GenServer.cast(pid, :terminate)
#      end
#    end)
#  end
#
#  # ---------------------
#  #       Helpers
#  # ---------------------
#
#  def get_registry() do
#    Registry.select(:peer_registry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
#  end
#
#  def get_peers() do
#    Supervisor.which_children(__MODULE__)
#  end
#
#  def kill() do
#    Supervisor.stop(__MODULE__, :normal)
#  end
end
