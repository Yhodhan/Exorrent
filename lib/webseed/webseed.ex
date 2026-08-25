defmodule Exorrent.Webseed do
  alias Webseed.Worker

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
    sup = Exorrent.TorrentSession.webseed_sup_name(torrent.info_hash)
    DynamicSupervisor.start_child(sup, {Worker, state})
  end
end
