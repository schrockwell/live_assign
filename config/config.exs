import Config

config :phoenix, :json_library, Jason

# The bare minimum endpoint config to stand up LiveView tests
config :love_ex, LoveTest.Endpoint,
  live_view: [signing_salt: "Fwg_AlGquBjb5QDG"],
  secret_key_base: "whoa"
