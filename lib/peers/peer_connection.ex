defmodule Exorrent.PeerConnection do
  use GenServer
  require Logger
  # -------------------
  #   GenServer calls
  # -------------------

  # initial states:
  #  peer: {ip, port}
  def start_link(initial_state),
    do: GenServer.start_link(__MODULE__, initial_state, name: via_tuple(initial_state))

  def peer_connect(name),
    do: GenServer.cast(name, :connect)

  def peer_health(name),
    do: GenServer.call(name, :status)

  # ----------------------
  #   GenServer functions
  # ----------------------
  def init(state),
    do: {:ok, state}

  def handle_cast(:connect, state) do
    {ip, port} = state.peer

    case :gen_tcp.connect(ip, port, [:binary, {:active, true}]) do
      {:ok, socket} ->
        Logger.debug("succesfull connection")
        new_state = Map.put(state, :socket, socket)
        {:noreply, new_state}

      {:error, reason} ->
        Logger.debug("Failed to connect #{inspect(ip)}:#{port} reason=#{inspect(reason)}")
        #        Logger.flush()
        {:noreply, state}
    end
  end

  def handle_call(:peer_status, _from, state) do
    socket = Map.get(state, :socket)

    if is_nil(socket) do
      {:reply, :not_connected, state}
    else
      {:reply, :connected, state}
    end
  end

  def handle_call(:status, _from, state),
    do: {:reply, :alive, state}

  # ---------------------
  #     Name helper
  # ---------------------
  defp via_tuple(initial_value) do
    {:via, Registry, {:peer_registry, initial_value}}
  end
end
