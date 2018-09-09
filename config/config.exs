use Mix.Config

config :logger, :console, level: if(is_nil(System.get_env("DEBUG")), do: :error, else: :debug)
