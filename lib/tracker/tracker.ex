defmodule Exorrent.Tracker do
  use GenServer

  def get_peers(torrent) do
    announce = torrent["announce"]
    announce_list = torrent["announce-list"]

    trackers = get_trackers_list(announce, announce_list)
    # get udp for now
    url = get_udp_tracker(trackers)

    # this forces ipv4
    {:ok, socket} = :gen_udp.open(0, [:binary, :inet, {:active, false}])
    {:ok, ip_address} = get_ip_from_host(url.host)
    # create the asynchronous tracker
    {:ok, _pid} = start_link(%{socket: socket, ip_address: ip_address, url: url})

    msg = connection_req()

    udp_message(msg)

    udp_response()
  end

  def announce(torrent, conn_id) do
    _msg = announce_req(conn_id, torrent)
  end

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ []),
    do: GenServer.start_link(__MODULE__, state, name: __MODULE__)

  def udp_message(msg),
    do: GenServer.cast(__MODULE__, {:send_udp, msg})

  def udp_response(),
    do: GenServer.call(__MODULE__, :udp_response)

  def get_tracker_data(),
    do: GenServer.call(__MODULE__, :state)

  def health(),
    do: send(__MODULE__, :health)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state),
    do: {:ok, state}

  def handle_cast({:send_udp, msg}, state) do
    send_udp_message(state.socket, state.ip_address, state.url.port, msg)
    {:noreply, state}
  end

  # debugging reasons, check the state of the gen server
  def handle_call(:state, _from, state),
    do: {:reply, state, state}

  # check if response from the tracker was get
  def handle_call(:udp_response, _from, state) do
    case :gen_udp.recv(state.socket, 0, 5000) do
      {:ok, {_from_ip, _from_port, received_msg}} ->
        response = process_message(received_msg)
        {:reply, response, state}

      {:error, :timeout} ->
        IO.puts("Failed to received msg in 5 seconds")
        {:reply, :timeout, state}

      {:error, reason} ->
        IO.puts("Failed to received msg: #{inspect(reason)}")
        {:reply, :failed, state}
    end
  end

  def handle_info(:health, state) do
    IO.puts("i am alive")

    {:noreply, state}
  end

  def handle_info(:death, state) do
    :gen_udp.close(state.socket)
    {:stop, :normal, state}
  end

  # ------------------
  # Private functions
  # ------------------

  defp get_trackers_list(announce, announce_list) do
    unless is_nil(announce_list) do
      List.flatten(announce_list)
    else
      [announce]
    end
  end

  defp get_udp_tracker(trackers) do
    Enum.map(trackers, fn t -> URI.parse(t) end)
    |> Enum.filter(fn uri -> uri.scheme == "udp" end)
    |> hd()
  end

  defp get_ip_from_host(raw_host) do
    host = to_charlist(raw_host)

    case :inet.gethostbyname(host) do
      {:ok, {:hostent, _hostname, _aliases, _addrtype, _len, [ip_address | _]}} ->
        {:ok, ip_address}

      {:error, reason} ->
        IO.puts("Failed to resolve host #{IO.inspect(reason)}")
        {:error, reason}
    end
  end

  defp send_udp_message(socket, ip_address, port, message) do
    IO.puts("Sending message to #{inspect(ip_address)}:#{port}")

    port = port || 6969

    :gen_udp.send(socket, ip_address, port, message)

    IO.puts("Message sent. waiting for response ..")
  end

  defp process_message(response) do
    case response do
      <<0::32, tx_id::32, conn_id::64>> ->
        {:connection, tx_id, conn_id}

      _ ->
        :unknown_operation
    end
  end

  defp connection_req() do
    protocol_id = 0x41727101980
    tx_id = :crypto.strong_rand_bytes(4)

    <<protocol_id::64, 0::32, tx_id::binary>>
  end

  defp announce_req(connection_id, _torrent, _port \\ 6881) do
    action = 1
    tx_id = :crypto.strong_rand_bytes(4)

    <<connection_id::64, action::32, tx_id::binary>>
  end
end
