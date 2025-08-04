defmodule Exorrent do
  alias BencodeDecoder.Decoder

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         {:ok, decode, _} <- Decoder.decode_bencode(bencode) do
      {:ok, decode}
    end
  end

  def exorrent() do
    {:ok, torrent} = read_torrent("puppy.torrent")
    IO.inspect(torrent)

    url = url(torrent)

    socket = :gen_udp.open(0, [:binary])

    {:ok, ip_address} = get_ip_from_host(url.host)

    send_udp_message(socket, ip_address, url.port, "hello?")
  end

  # private functions

  defp url(torrent) do
    torrent["announce"]
    |> to_string()
    |> URI.parse()
  end

  defp get_ip_from_host(host) do
    case :inet.gethostbyname(host) do
      {:ok, {:host, _hostname, :inet, [ip_address]}} ->
        {:ok, ip_address}

      {:error, reason} ->
        IO.puts("Failed to resolve host #{IO.inspect(reason)}")
        {:error, reason}
    end
  end

  #
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
