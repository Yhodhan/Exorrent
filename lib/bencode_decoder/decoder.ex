defmodule BencodeDecoder.Decoder do
  @moduledoc """
  Documentation for `Exorrent`.
  """

  def parse_bencode(bencode) when is_binary(bencode) do
    bencode
    |> :binary.bin_to_list()
    |> parse_bencode()
  end

  def parse_bencode(bencode) do
    case hd(bencode) do
      ?d ->
        parse_dictionary(tl(bencode))

      ?l ->
        parse_list(tl(bencode))

      ?i ->
        parse_integer(tl(bencode))

      _ ->
        parse_string(bencode)
    end
  end

  # if it is a dictionary
  # check if it is not the end
  # if is not then pick up the key and decode the value from the binary
  def parse_dictionary(dic, map \\ %{}) do
    case hd(dic) do
      ?e ->
        {:ok, map, tl(dic)}

      _ ->
        {:ok, key, rest} = parse_bencode(dic)
        {:ok, value, rest} = parse_bencode(rest)

        parse_dictionary(rest, Map.put(map, key, value))
    end
  end

  def parse_list(bencode, list \\ []) do
    case hd(bencode) do
      ?e ->
        {:ok, list, tl(bencode)}

      _ ->
        {:ok, result, rem} = parse_bencode(bencode)
        list = list ++ [result]
        parse_list(rem, list)
    end
  end

  def parse_integer(bencode) do
    digits = Enum.take_while(bencode, fn b -> b != ?e end)
    {num, _} = digits |> to_string |> Integer.parse()

    # remove int from the bitstring
    remain = Enum.drop(bencode, length(digits) + 1)
    {:ok, num, remain}
  end

  def parse_string(bencode) do
    digits = Enum.take_while(bencode, fn s -> s != ?: end)
    {s, _} = digits |> to_string |> Integer.parse()
    # drop the digit caracters all up to : including it
    word = Enum.drop(bencode, length(digits) + 1)
    {:ok, :binary.list_to_bin(Enum.take(word, s)), Enum.drop(word, s)}
  end
end
