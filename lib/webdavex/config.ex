defmodule Webdavex.Config do
  @hackney_options_whitelist [:pool, :ssl_options, :connect_options, :proxy, :insecure, :connect_timeout, :recv_timeout]
  @default_headers []
  @default_hackney_options []

  @moduledoc """
  `Webdavex.Client` configuration.

  ## Options

  ### :base_url, required.
  Schema, host, port and root path of webdav endpoint.
  Example: "https://myhost.com:8081/something/webdav".

  ### :headers, default: #{inspect(@default_headers)}.
  A list of HTTTP headers that will be added to each of `Webdavex.Client` request.
  Example: [{"X-Webdav-Client", "webdavex"}].

  HTTP basic auth could be implemented using `:headers` options:
  ```
  username = "client"
  password = "supersecret"
  digest = :base64.encode(username <> ":" <> password)

  headers = [{"Authorization", "Basic " <> digest}]
  ```
  ### :hackney_options, default: #{inspect(@default_hackney_options)}.
  Options are limited to #{inspect(@hackney_options_whitelist)}, refer to `:hackney.request/5`
  [docs](https://hexdocs.pm/hackney/) for detailed information.

  ## Examples

      iex> Webdavex.Config.new(base_url: "http://myhost.com")
      %Webdavex.Config{
        base_url: URI.parse("http://myhost.com"),
        hackney_options: #{inspect(@default_hackney_options)},
        headers: #{inspect(@default_headers)}
      }

      iex> Webdavex.Config.new(
      ...>   base_url: "http://myhost.com",
      ...>   headers: [{"X-Something", "value"}],
      ...>   hackney_options: [pool: :webdav, foo: 1]
      ...> )
      %Webdavex.Config{
        base_url: URI.parse("http://myhost.com"),
        headers: [{"X-Something", "value"}],
        hackney_options: [pool: :webdav]
      }
  """

  @type t :: %__MODULE__{base_url: URI.t(), hackney_options: Keyword.t(), headers: Keyword.t()}
  defstruct [:base_url, :hackney_options, :headers]

  @spec new(map | Keyword.t() | __MODULE__.t()) :: __MODULE__.t()
  @doc "Converts enumerable into `Webdavex.Config` struct."
  def new(%__MODULE__{} = config), do: config

  def new(opts) do
    base_url = Access.get(opts, :base_url, nil) || raise(ArgumentError, "[#{__MODULE__}] `base_url` is missing.")

    struct(
      __MODULE__,
      base_url: URI.parse(base_url),
      hackney_options: Keyword.get(opts, :hackney_options, @default_hackney_options) |> filter_hackney_opts(),
      headers: Keyword.get(opts, :headers, @default_headers)
    )
  end

  defp filter_hackney_opts(opts) do
    Enum.reject(opts, fn {k, _v} -> k not in @hackney_options_whitelist end)
  end
end
