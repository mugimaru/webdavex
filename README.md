# Webdavex

[hackney](https://github.com/benoitc/hackney) based WebDAV client.

Webdavex aimed to work with [nginx implementation of WebDAV](https://nginx.org/en/docs/http/ngx_http_dav_module.html)
which means that it does not support `PROPFIND`, `PROPPATCH`, `LOCK` and `UNLOCK` methods.

**Work in progress, TODO**:
* publish hex package
* publish docs

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `webdavex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:webdavex, "~> 0.1.0"}
  ]
end
```

## Quick start

```elixir
defmodule MyApp.WebdavClient do
  use Webdavex, base_url: "https://webdav.host:888"
end

MyApp.WebdavClient.put("image.png", {:file, Path.absname("files/image.png")})
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/webdavex](https://hexdocs.pm/webdavex).
