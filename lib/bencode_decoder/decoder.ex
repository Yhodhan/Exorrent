defmodule BencodeDecoder.Decoder do
  @moduledoc """
  Documentation for `Decoder`.
  """

  def decode_bencode(bencode) when is_binary(bencode) do
    bencode
    |> :binary.bin_to_list()
    |> decode_bencode()
  end

  def decode_bencode(bencode) do
    case hd(bencode) do
      ?d ->
        decode_dictionary(tl(bencode))

      ?l ->
        decode_list(tl(bencode))

      ?i ->
        decode_integer(tl(bencode))

      _ ->
        decode_string(bencode)
    end
  end

  # if it is a dictionary:
  # 1- check if it is not the end
  # 2- if is not then pick up the key and decode the value from the binary
  def decode_dictionary(dic, map \\ %{}) do
    case hd(dic) do
      ?e ->
        {:ok, map, tl(dic)}

      _ ->
        {:ok, key, rest} = decode_bencode(dic)
        {:ok, value, rest} = decode_bencode(rest)

        decode_dictionary(rest, Map.put(map, key, value))
    end
  end

  def decode_list(bencode, list \\ []) do
    case hd(bencode) do
      ?e ->
        {:ok, list, tl(bencode)}

      _ ->
        {:ok, result, rem} = decode_bencode(bencode)
        list = list ++ [result]
        decode_list(rem, list)
    end
  end

  def decode_integer(bencode) do
    digits = Enum.take_while(bencode, fn b -> b != ?e end)
    {num, _} = parse_digits(digits)

    # remove int from the bitstring
    remain = Enum.drop(bencode, length(digits) + 1)
    {:ok, num, remain}
  end

  def decode_string(bencode) do
    digits = Enum.take_while(bencode, fn s -> s != ?: end)
    {s, _} = parse_digits(digits)
    # drop the digit caracters all up to : including it
    word = Enum.drop(bencode, length(digits) + 1)
    {:ok, :binary.list_to_bin(Enum.take(word, s)), Enum.drop(word, s)}
  end

  # private functions
  defp parse_digits(digits) do
    digits
    |> to_string
    |> Integer.parse()
  end
end
