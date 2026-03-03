defmodule Exorrent.InfoHash do
  def raw_info_hash(torrent_binary) do
    info_key = "4:info"

    case :binary.match(torrent_binary, info_key) do
      {pos, _} ->
        info_start = pos + byte_size(info_key)
        info_binary = extract_dictionary(torrent_binary, info_start)
        {:ok, :crypto.hash(:sha, info_binary)}

      :nomatch ->
        {:error, :info_not_found}
    end
  end

  # Extract full bencoded dictionary starting at given offset
  defp extract_dictionary(binary, start_pos) do
    <<_::binary-size(start_pos), rest::binary>> = binary

    do_extract(rest, 0, 0)
  end

  # Walk through the binary counting nested dictionaries/lists
  defp do_extract(<<"d", rest::binary>>, 0, size) do
    do_extract(rest, 1, size + 1)
  end

  defp do_extract(<<"d", rest::binary>>, depth, size) do
    do_extract(rest, depth + 1, size + 1)
  end

  defp do_extract(<<"l", rest::binary>>, depth, size) do
    do_extract(rest, depth + 1, size + 1)
  end

  defp do_extract(<<"e", rest::binary>>, 1, size) do
    total_size = size + 1
    <<info::binary-size(total_size), _::binary>> = <<?d, rest::binary>>
    info
  end

  defp do_extract(<<"e", rest::binary>>, depth, size) do
    do_extract(rest, depth - 1, size + 1)
  end

  # integer
  defp do_extract(<<"i", rest::binary>>, depth, size) do
    {_, rest2} = take_until(rest, ?e)
    do_extract(rest2, depth, size + byte_size(rest) - byte_size(rest2) + 1)
  end

  # string
  defp do_extract(binary, depth, size) do
    {len_str, <<":", rest::binary>>} = take_until(binary, ?:)
    len = String.to_integer(len_str)

    <<_str::binary-size(len), rest2::binary>> = rest

    consumed =
      byte_size(len_str) + 1 + len

    do_extract(rest2, depth, size + consumed)
  end

  defp take_until(binary, delimiter) do
    {pos, _} = :binary.match(binary, <<delimiter>>)
    <<part::binary-size(pos), rest::binary>> = binary
    {part, rest}
  end
end
