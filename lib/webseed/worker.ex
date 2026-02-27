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
    Logger.info("=== Init connection webseed worker ====")
    {:noreply, state, {:continue, :cycle}}
  end

  def handle_continue(:cycle, state) do
    base_url = state.url

    url =
      if String.ends_with?(base_url, "/") do
        base_url <> state.torrent.name
      else
        base_url <> "/" <> state.torrent.name
      end

    %{piece_length: length, size: size} = state.torrent

    with {:ok, piece_index} <- PieceManager.request_work(),
         {:ok, piece} <- fetch_piece(url, piece_index, length, size) do
      Logger.info("=== Piece obtained: #{piece_index} ===")
      PieceManager.validate_piece(piece)
      {:noreply, state, {:continue, :cycle}}
    else
      {:none, _} ->
        {:stop, :normal, state}
        {:noreply, state, {:continue, :cycle}}

      {:error, error} ->
        Logger.error("=== Error fetching piece: #{error}")
        {:noreply, state, {:continue, :cycle}}
    end
  end

  # ----------- PRIVATE FUNCTIONS -------------
  defp fetch_piece(url, piece_index, piece_length, total_size) do
    Logger.info("Fetch piece index #{piece_index} from #{to_charlist(url)}")

    start_byte = piece_index * piece_length
    end_byte = min(start_byte + piece_length - 1, total_size - 1)

    headers = [
      {'Range', to_charlist("bytes=#{start_byte}-#{end_byte}")}
    ]

    request = {to_charlist(url), headers}

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
