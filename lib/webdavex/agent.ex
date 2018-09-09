defmodule Webdavex.Agent do
  @moduledoc """
  Wraps `Webdavex` into `Agent` in order to change configuration during runtime.

      defmodule MyClient
        use Webdavex.Agent, base_url: "http://placeholder"
      end

      {:ok, _pid} = MyClient.start_link(base_url: "http://webdav.host")
      MyClient.update_config(base_url: "https://webdav.host", headers: [{"foo", "bar"}])
      MyClient.get("image.png")
  """

  defmacro __using__(default_config) do
    quote do
      use Agent
      use Webdavex, unquote(default_config)

      @spec start_link(Keyword.t() | map | Webdavex.Config.t()) :: {:ok, pid}
      def start_link(config \\ @config) do
        Agent.start_link(fn -> Webdavex.Config.new(config) end, name: __MODULE__)
      end

      @spec update_config(Keyword.t() | map | Webdavex.Config.t()) :: Webdavex.Config.t()
      def update_config(map) do
        Agent.update(__MODULE__, Webdavex.Config.new(map))
      end

      @spec config :: Webdavex.Config.t()
      def config do
        Agent.get(__MODULE__, fn config -> config end)
      end
    end
  end
end
