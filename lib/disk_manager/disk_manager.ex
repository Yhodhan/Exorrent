defmodule DiskManager do
  use GenServer

  # -------------------
  #  GenServer calls
  # -------------------

  def start_link(torrent \\ %{}),
    do: GenServer.start_link(__MODULE__, torrent)

  def write_piece(piece_index, piece),
    do: GenServer.cast(__MODULE__, {:write, piece_index, piece})

  # ----------------------
  #  GenServer functions
  # ----------------------

  def init(torrent) do
    Process.flag(:trap_exit, true)
    {:ok, fd} = File.open(torrent.name, [:raw, :read, :write, :binary])

    disk_state = %{fd: fd, piece_length: torrent.piece_length}
    {:ok, disk_state}
  end

  def handle_call(
        {:write, piece_index, piece},
        %{fd: fd, piece_length: piece_length} = disk_state
      ) do
    offset = piece_index * piece_length

    :ok = :file.pwrite(fd, offset, piece)

    {:noreply, disk_state}
  end
end
