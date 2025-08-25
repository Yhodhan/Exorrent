defmodule Exorrent.Encoder do
  @moduledoc """
  Documentation for `Encoder`.
  """

  def encode_bencode(data) when is_map(data),
    do: encode_map(data)

  def encode_bencode(data) when is_integer(data),
    do: encode_integer(data)

  def encode_bencode(data) when is_list(data),
    do: encode_list(data)

  def encode_bencode(data) when is_bitstring(data),
    do: encode_string(data)

  def encode_bencode(data) when is_atom(data),
    do: encode_atom(data)

  def encode_map(map) do
    keys = Map.keys(map)
    values = Map.values(map)

    encode_keys = Enum.map(keys, fn k -> encode_bencode(k) end)
    encode_values = Enum.map(values, fn v -> encode_bencode(v) end)

    bin_data =
      Enum.zip(encode_keys, encode_values)
      |> Enum.map(fn {k, v} -> k <> v end)
      |> Enum.reduce(<<>>, fn e, acc -> acc <> e end)

    <<?d, bin_data::binary, ?e>>
  end

  def encode_list(list) do
    bin_data =
      list
      |> Enum.map(fn elem -> encode_bencode(elem) end)
      |> Enum.reduce(<<>>, fn e, acc -> acc <> e end)

    <<?l, bin_data::binary, ?e>>
  end

  def encode_integer(int) do
    <<?i, Integer.to_string(int)::binary, ?e>>
  end

  def encode_atom(atom) do
    Atom.to_string(atom)
    |> encode_string()
  end

  def encode_string(str) do
    len = String.length(str)
    <<Integer.to_string(len)::binary, ?:, str::binary>>
  end
end
