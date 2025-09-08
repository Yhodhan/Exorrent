defmodule Tracker.UdpTracker do
  alias Peers.Messages

  use GenServer
  require Logger

  def send_request(%URI{scheme: "udp"} = url, torrent) do
    with {:ok, socket} <- :gen_udp.open(0, [:binary, :inet, {:active, false}]),
         {:ok, ip_address} <- get_ip_from_host(url.host),
         {:ok, pid} <- start_link(%{socket: socket, ip_address: ip_address, url: url}),
         do: udp_connection(pid, torrent)
  end

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ []),
    do: GenServer.start_link(__MODULE__, state)

  def udp_message(pid, msg, port \\ 6969),
    do: GenServer.cast(pid, {:send_udp, msg, port})

  def udp_response(pid),
    do: GenServer.cast(pid, {:udp_response, self()})

  def get_tracker_data(pid),
    do: GenServer.cast(pid, :state)

  def conn_down(pid),
    do: send(pid, :death)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state),
    do: {:ok, state}

  def handle_cast({:send_udp, msg, port}, state) do
    Logger.info("=== Sending message to #{inspect(state.ip_address)}:#{port}")

    :gen_udp.send(state.socket, state.ip_address, port, msg)

    Logger.info("=== Message sent. waiting for response ..")

    {:noreply, state}
  end

  def handle_cast({:udp_response, pid}, state) do
    case :gen_udp.recv(state.socket, 0, 15000) do
      {:ok, {_from_ip, _from_port, received_msg}} ->
        Logger.info("=== Response received")
        response = Messages.parse_udp_message(received_msg)
        send(pid, {:ok, response})
        {:noreply, state}

      {:error, :timeout} ->
        Logger.error("=== Failed to received msg in 5 seconds")
        send(pid, :timeout)
        {:noreply, state}

      {:error, reason} ->
        Logger.error("=== Failed to received msg: #{inspect(reason)}")
        send(pid, :error)
        {:noreply, state}
    end
  end

  # debugging reasons, check the state of the gen server
  def handle_call(:state, _from, state),
    do: {:reply, state, state}

  # check if response from the tracker was get
  def handle_info(:death, state) do
    :gen_udp.close(state.socket)
    {:stop, :normal, state}
  end

  # ------------------
  # Private functions
  # ------------------

  defp udp_connection(pid, torrent) do
    msg = Messages.udp_connection_req()
    udp_message(pid, msg)

    with :ok <- udp_response(pid),
         {:ok, connection} <- await_response(),
         :ok <- announce(pid, connection.conn_id, torrent),
         {:ok, announce} <- await_response() do
      announce.peers
    else
      _ ->
        conn_down(pid)
        []
    end
  end

  defp announce(pid, conn_id, torrent) do
    msg = Messages.udp_announce_req(conn_id, torrent)
    udp_message(pid, msg)

    udp_response(pid)
  end

  defp await_response() do
    receive do
      {:ok, response} ->
        {:ok, response}

      _ ->
        :error
    end
  end

  defp get_ip_from_host(raw_host) do
    host = to_charlist(raw_host)

    case :inet.gethostbyname(host) do
      {:ok, {:hostent, _hostname, _aliases, _addrtype, _len, [ip_address | _]}} ->
        {:ok, ip_address}

      {:error, reason} ->
        Logger.error("=== Failed to resolve host #{inspect(reason)}")
        {:error, reason}
    end
  end
end
