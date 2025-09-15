defmodule Peers.DownloadTable do
  # ---------------
  #     Schema
  # ---------------
  # key: piece hash,
  # status: incomplete|download|complete
  # downloaded_bytes: integer
  # total_size: integer

  def create_table() do
    :ets.new(:piece_table, [:set, :public, :named_table])
  end

  def fill_table(pieces, size) do
    pieces
    |> Enum.each(fn hash -> :ets.insert(:piece_table, {hash, :incomplete, 0, size}) end)
  end
end
