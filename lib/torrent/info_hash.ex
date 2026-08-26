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

  defp extract_dictionary(binary, start_pos) do
    <<_::binary-size(^start_pos), rest::binary>> = binary
    len = do_extract(rest, 0, 0)
    binary_part(rest, 0, len)
  end

  defp do_extract(<<"d", rest::binary>>, 0, size), do: do_extract(rest, 1, size + 1)
  defp do_extract(<<"d", rest::binary>>, depth, size), do: do_extract(rest, depth + 1, size + 1)
  defp do_extract(<<"l", rest::binary>>, depth, size), do: do_extract(rest, depth + 1, size + 1)
  defp do_extract(<<"e", _rest::binary>>, 1, size), do: size + 1
  defp do_extract(<<"e", rest::binary>>, depth, size), do: do_extract(rest, depth - 1, size + 1)

  defp do_extract(<<"i", rest::binary>>, depth, size) do
    {digits, after_digits} = take_until(rest, ?e)
    <<"e", rest2::binary>> = after_digits
    do_extract(rest2, depth, size + 1 + byte_size(digits) + 1)
  end

  defp do_extract(binary, depth, size) do
    {len_str, <<":", rest::binary>>} = take_until(binary, ?:)
    len = String.to_integer(len_str)
    <<_str::binary-size(^len), rest2::binary>> = rest
    consumed = byte_size(len_str) + 1 + len
    do_extract(rest2, depth, size + consumed)
  end

  defp take_until(binary, delimiter) do
    {pos, _} = :binary.match(binary, <<delimiter>>)
    <<part::binary-size(^pos), rest::binary>> = binary
    {part, rest}
  end
end
