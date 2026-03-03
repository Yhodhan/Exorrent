defmodule Exorrent.Webseed do
  alias Webseed.Worker
  require Logger

  @max_workers 6

  def handle_webseeds(torrent) do
    torrent.urls
    |> init_workers(torrent)
  end

  def init_workers(urls, torrent) do
    urls
    |> Enum.take(@max_workers)
    |> Enum.each(fn url -> init_worker(url, torrent) end)
  end

  def init_worker(url, torrent) do
    state = %{url: url, torrent: torrent}
    {:ok, _pid} = Worker.start_link(state)
  end
end
