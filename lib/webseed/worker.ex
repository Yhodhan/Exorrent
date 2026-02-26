defmodule Webseed.Worker do
  use GenServer
  require Logger

  @moduledoc """
    This module handles the worker logics, which deals with the messages that are sent to the  
    server seeds. 
  """
  alias Exorrent.PieceManager

  # -------------------
  #   GenServer calls
  # -------------------

  def start_link(state \\ %{}) do
    GenServer.start_link(__MODULE__, state)
  end

  # -----------------------
  #   GenServer functions
  # -----------------------

  def init(state) do
    Process.flag(:trap_exit, true)
    Process.send_after(self(), :connect, 1)
    {:ok, state}
  end

  def handle_info(:connect, state) do
    {:noreply, state, {:continue, :cycle}}
  end

  def handle_continue(:cycle, state) do
    url = state.url
    %{piece_length: length, size: size} = state.torrent

    with {:ok, piece_index} <- PieceManager.request_work(),
         {:ok, piece} <- fetch_piece(url, piece_index, length, size) do
         PieceManager.validate_piece(piece)
    else
      {:none, _} ->
        {:stop, :normal, state}

      {:error, error} ->
        Logger.error("=== Error fetching piece: #{error}")
        {:noreply, state, {:continue, :cycle}}
    end
  end

  # ----------- PRIVATE FUNCTIONS -------------
  defp fetch_piece(url, piece_index, piece_length, total_size) do
    start_byte = piece_index * piece_length
    end_byte = min(start_byte + piece_length - 1, total_size - 1)

    headers = [
      {"Range", "bytes=#{start_byte}-#{end_byte}"}
    ]

    request = {String.to_charlist(url), headers}

    http_opts = []
    opts = [body_format: :binary]

    case :httpc.request(:get, request, http_opts, opts) do
      {:ok, {{_, 206, _}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_, 200, _}, _headers, body}} ->
        # Server ignore Range header
        # You must manually slice it
        expected_size = end_byte - start_byte + 1
        {:ok, binary_part(body, start_byte, expected_size)}

      {:ok, {{_, status, _}, _, _}} ->
        {:error, {:unexpected_status, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
