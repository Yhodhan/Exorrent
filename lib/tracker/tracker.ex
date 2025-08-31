defmodule Exorrent.Tracker do
  alias Exorrent.TorrentParser

  use GenServer

  def get_peers(torrent) do
    trackers = TorrentParser.get_trackers_list(torrent)
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

  def announce(conn_id, torrent) do
    msg = announce_req(conn_id, torrent)

    udp_message(msg)

    udp_response()
  end

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ []),
    do: GenServer.start_link(__MODULE__, state, name: __MODULE__)

  def udp_message(msg, port \\ 6969),
    do: GenServer.cast(__MODULE__, {:send_udp, msg, port})

  def udp_response(),
    do: GenServer.call(__MODULE__, :udp_response)

  def get_tracker_data(),
    do: GenServer.call(__MODULE__, :state)

  def health(),
    do: send(__MODULE__, :health)

  def conn_down(),
    do: send(__MODULE__, :death)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state),
    do: {:ok, state}

  def handle_cast({:send_udp, msg, port}, state) do
    send_udp_message(state.socket, state.ip_address, port, msg)
    {:noreply, state}
  end

  # debugging reasons, check the state of the gen server
  def handle_call(:state, _from, state),
    do: {:reply, state, state}

  # check if response from the tracker was get
  def handle_call(:udp_response, _from, state) do
    case :gen_udp.recv(state.socket, 0, 15000) do
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

    :gen_udp.send(socket, ip_address, port, message)

    IO.puts("Message sent. waiting for response ..")
  end

  defp process_message(msg) do
    case msg do
      # connection
      <<0::32, tx_id::32, conn_id::64>> ->
        %{action: :connection, tx_id: tx_id, conn_id: conn_id}

      # announce
      <<1::32, tx_id::32, interval::32, leechers::32, seeders::32, peers::binary>> ->
        peers_ips = parse_peers(peers)

        %{
          action: :announce,
          tx_id: tx_id,
          interval: interval,
          leechers: leechers,
          seeders: seeders,
          peers: peers_ips
        }

      _ ->
        :unknown_operation
    end
  end

  defp parse_peers(<<>>), do: []

  defp parse_peers(<<a, b, c, d, port::16, rest::binary>>) do
    ip = {a, b, c, d}
    peer = {ip, port}
    [peer] ++ parse_peers(rest)
  end

  defp connection_req() do
    protocol_id = 0x41727101980
    tx_id = :crypto.strong_rand_bytes(4)

    <<protocol_id::64, 0::32, tx_id::binary>>
  end

  defp announce_req(connection_id, torrent, port \\ 6881) do
    action = 1
    tx_id = :crypto.strong_rand_bytes(4)
    info_hash = TorrentParser.get_info_hash(torrent)
    downloaded = 0
    peer_id = :crypto.strong_rand_bytes(20)
    left = TorrentParser.size(torrent)
    uploaded = 0
    event = 0
    ip_address = 0
    key = :crypto.strong_rand_bytes(4)
    num_want = -1

    <<connection_id::64, action::32, tx_id::binary, info_hash::binary, peer_id::binary, left::64,
      downloaded::64, uploaded::64, event::32, ip_address::32, key::binary, num_want::signed-32,
      port::16>>
  end
end
