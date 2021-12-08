[![hex.pm version](https://img.shields.io/hexpm/v/webdavex.svg?style=flat)](https://hex.pm/packages/webdavex)
[![API Docs](https://img.shields.io/badge/api-docs-yellow.svg?style=flat)](https://hexdocs.pm/webdavex/)
[![Build Status](https://travis-ci.org/mugimaru73/webdavex.svg?branch=master)](https://travis-ci.org/mugimaru73/webdavex)

# Webdavex

[hackney](https://github.com/benoitc/hackney) based WebDAV client.

Webdavex aimed to work with [nginx implementation of WebDAV](https://nginx.org/en/docs/http/ngx_http_dav_module.html)
which means it does not support `PROPFIND`, `PROPPATCH`, `LOCK` and `UNLOCK` methods.

## Installation

```elixir
def deps do
  [
    {:webdavex, "~> 0.3.0"}
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

Refer to [Webdavex.Client](https://hexdocs.pm/webdavex/Webdavex.Client.html) API docs for more details.
