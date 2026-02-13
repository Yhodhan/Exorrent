defmodule DiskManager do
  use GenServer

  require Logger

  # -------------------
  #  GenServer calls
  # -------------------

  def start_link(torrent \\ %{}),
    do: GenServer.start_link(__MODULE__, torrent, name: __MODULE__)

  def write_piece(piece_index, piece),
    do: GenServer.call(__MODULE__, {:write, piece_index, piece})

  # ----------------------
  #  GenServer functions
  # ----------------------

  def init(torrent) do
    Logger.info("=== Init Disk Manager ===")

    Process.flag(:trap_exit, true)
    {:ok, fd} = File.open(torrent.name, [:raw, :read, :write, :binary])

    #allocate full 0s
    :file.pwrite(fd, torrent.total_pieces - 1, <<0>>)

    disk_state = %{fd: fd, piece_length: torrent.piece_length}

    {:ok, disk_state}
  end

  def handle_call(
        {:write, piece_index, piece},
        _from,
        %{fd: fd, piece_length: piece_length} = disk_state
      ) do
    offset = piece_index * piece_length

    Logger.debug("piece index: #{piece_index}")
    Logger.debug("=== About to write in offset #{offset} ===")

    case :file.pwrite(fd, offset, piece) do
      :ok ->
        {:reply, :ok, disk_state}

      {:error, reason} ->
        Logger.error("Error writing to disk: #{reason}")
        {:reply, :error, disk_state}
    end
  end
end
