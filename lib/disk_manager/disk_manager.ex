defmodule DiskManager do
  use GenServer

  # -------------------
  #  GenServer calls
  # -------------------

  def start_link(disk_state \\ %{}),
    do: GenServer.start_link(__MODULE__, disk_state)

  def write_piece(piece_index, piece),
    do: GenServer.cast(__MODULE__, {:write, piece_index, piece})

  # ----------------------
  #  GenServer functions
  # ----------------------

  def init(disk_state) do
    Process.flag(:trap_exit, true)
    {:ok, fd} = File.open("obs.torrent", [:raw, :read, :write, :binary])
    {:ok, %{disk_state | fd: fd}}
  end

  def handle_call({:write, piece_index, piece}, %{fd: fd} = disk_state) do
    {:noreply, disk_state}
  end
end
