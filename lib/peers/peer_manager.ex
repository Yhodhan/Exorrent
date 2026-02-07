defmodule Peers.PeerManager do
  use GenServer

  @doc """
    The function of this module is to manage the workers and assigned them pieces to download 
    or terminated them if neccessary
  """

  def start_link({peers, pieces}),
    do: GenServer.start_link(__MODULE__, {peers, pieces}, name: __MODULE__)

  # store the received bitmap from a worker
  def store_bitfield(pid, bitmap),
    do: GenServer.cast(__MODULE__, {:store_bitfield, pid, bitmap})

  # store the received piece from a have message of a worker
  def store_piece(pid, piece),
    do: GenServer.cast(__MODULE__, {:store_piece, pid, piece})

  def request_work(pid),
    do: GenServer.call(__MODULE__, {:request_work, pid})

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init({peers, pieces}) do
    # build map of peers
    peers_map =
      for pid <- peers, into: %{} do
        {pid, MapSet.new()}
      end

    missing_pieces = MapSet.new(pieces)

    {:ok, %{peers_map: peers_map, missing: missing_pieces}}
  end

  def handle_cast({:store_bitfield, pid, bitmap}, %{peers_map: peers_map} = state) do
    merged_sets =
      peers_map
      |> Map.get(pid)
      |> MapSet.union(bitmap)

    peers_map = Map.put(peers_map, pid, merged_sets)
    {:noreply, peers_map}
  end

  def handle_cast({:store_piece, pid, piece}, %{peers_map: peers_map} = state) do
    pieces_set =
      peers_map
      |> Map.get(pid)
      |> MapSet.put(piece)

    peers_map = Map.put(peers_map, pid, pieces_set)
    {:noreply, peers_map}
  end

  def handle_call({:request_work, pid}, _from, state) do
    peers_map = state.peers_map
    missings = state.missing

    candidates =
      peers_map
      |> Map.get(peers_map, pid)
      |> MapSet.intersection(missings)

    case MapSet.size(candidates) do
      0 ->
        {:reply, :none, state}

      _ ->
        piece = Enum.at(candidates, 0)
        {:reply, piece, state}
    end
  end
end
