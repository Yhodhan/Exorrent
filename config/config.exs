import Config

config :exalia, :bootstrap_nodes, [
  {"router.bittorrent.com", 6881},
  {"dht.transmissionbt.com", 6881},
  {"router.utorrent.com", 6881}
]

config :exalia, :dht_port, 6882

config :exorrent, :torrent_port, 6881

config :logger,
  level: :debug

config :logger, :compile_time_purge_matching, [
  # Purge only :debug logs for the specific dependency application
  [application: :exalia, level_lower_than: :info]
]
