config :sample, Example.Endpoint,
  url: [host: "localhost"],
  pubsub_server: Example.PubSub,
  live_view: [signing_salt: "DIv4zwpo"]
