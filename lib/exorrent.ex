defmodule Exorrent do
  alias BencodeDecoder.Decoder

  def read_torrent(torrent) do
    with {:ok, bencode} <- File.read(torrent),
         {:ok, decode, _} <- Decoder.parse_bencode(bencode) do
      {:ok, decode}
    end
  end
end
