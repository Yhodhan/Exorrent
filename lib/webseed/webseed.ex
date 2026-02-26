defmodule Exorrent.Webseed do
  alias Webseed.Worker
  require Logger

  def handle_webseeds(torrent) do
    torrent.urls
    |> init_workers(torrent)
  end

  def init_workers(urls, torrent) do
    [url | _rest ] = urls
    init_worker(url, torrent)
    #urls
    #|> Enum.each(fn url ->  init_worker(url, torrent) end)
  end

  def init_worker(url, torrent) do
    state = %{url: url, torr: torrent}
    {:ok, pid} = Worker.start_link(state)
  end
end
