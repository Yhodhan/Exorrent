defmodule Tracker do
  use GenServer

  def create_tracker(torrent) do
    url = url(torrent["announce"])

    {:ok, socket} = :gen_udp.open(0, [:binary])

    IO.inspect(socket, label: "socket")

    {:ok, ip_address} = get_ip_from_host(url.host)

    # create the asynchronous tracker
    {:ok, _pid} = start_link()

    udp_message(socket, ip_address, url.port, "hello?")
  end

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ []),
    do: GenServer.start_link(__MODULE__, state, name: __MODULE__)

  def udp_message(socket, ip_address, port, msg),
    do: GenServer.cast(__MODULE__, {:send_udp, socket, ip_address, port, msg})

  def health(),
    do: send(__MODULE__, :health)

  # ----------------------
  #   GenServer functions
  # ----------------------

  def init(state),
    do: {:ok, state}

  def handle_cast({:send_udp, socket, ip_address, port, msg}, state) do
    send_udp_message(socket, ip_address, port, msg)
    {:noreply, state}
  end

  def handle_info(:health, state) do
    IO.puts("i am alive")
    {:noreply, state}
  end

  # ------------------
  # Private functions
  # ------------------

  defp url(announce) when is_bitstring(announce),
    do: URI.parse(announce)

  defp url(announce) do
    announce
    |> to_string()
    |> URI.parse()
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
    message_binary = message

    IO.puts("Sending message to #{inspect(ip_address)}:#{port}")
    :gen_udp.send(socket, ip_address, port, message_binary)
    IO.puts("Message sent. waiting for response ..")

    case :gen_udp.recv(socket, 0, 5000) do
      {:ok, {from_ip, from_port, received_msg}} ->
        IO.puts("\n Received message from #{inspect(from_ip)}:#{from_port}")
        IO.puts("Message is: #{inspect(received_msg)}")

      {:error, :timeout} ->
        IO.puts("no response received whithin 5 secods.")

      {:error, reason} ->
        IO.puts("Failed to received msg: #{inspect(reason)}")
    end

    :gen_udp.close(socket)
  end
end
