defmodule Webdavex.Client do
  @moduledoc """
  [hackney](https://github.com/benoitc/hackney) based WebDAV client.

  It is recommended to use `Webdavex` module to define your own client
  instead of using `Webdavex.Client` directly.

  With
      defmodule MyClient
        use Webdavex, base_url: "http://webdav.host"
      end

  you can write
      MyClient.get("image.png")

  instead of
      Webdavex.Config.new(base_url: "http://webdav.host") |> Webdavex.Client.get()
  """

  alias Webdavex.Config
  require Logger

  @spec head(Config.t(), path :: String.t()) :: {:ok, list({String.t(), String.t()})} | {:error, atom}
  @doc """
  Issues a HEAD request to webdav server.
  Returns response headers if target file exists.
  It migth be useful to check content type and size of file (Content-Type and Content-Length headers respectively).

  ### Examples

      MyClient.head("foo.jpg")
      {:ok, [
        {"Date", "Sun, 09 Sep 2018 18:13:00 GMT"},
        {"Content-Type", "image/jpeg"},
        {"Content-Length", "870883"},
        {"Last-Modified", "Sat, 08 Sep 2018 18:00:51 GMT"},
      ]}
  """
  def head(%Config{} = config, path) do
    case request(:head, path, [], "", config) do
      {:ok, 200, headers} ->
        {:ok, headers}

      error ->
        wrap_error(error)
    end
  end

  @spec get(Config.t(), path :: String.t()) :: {:ok, binary} | {:error, atom}
  @doc """
  Gets a file from webdav server.

  ### Examples

      MyClient.get("foo.png")
      {:ok, <<binary content>>}
  """
  def get(%Config{} = config, path) do
    with {:ok, 200, _, ref} <- request(:get, path, [], "", config),
         {:ok, body} <- :hackney.body(ref) do
      {:ok, body}
    else
      error ->
        wrap_error(error)
    end
  end

  @spec put(Config.t(), path :: String.t(), {:file, String.t()} | {:binary, binary}) ::
          {:ok, :created} | {:ok, :updated} | {:error, atom}
  @doc """
  Uploads local file or binary content to webdav server.

  Note that webdav specification only allows to create files in already existing folders
  which means thah you must call `mkcol/2` or `mkcol_recursive/2` manually.

  ### Examples
  Upload local file

      MyClient.put("image.png", {:file, "/home/username/img.png"})
      {:ok, :created}

  Upload custom binary content

      MyClient.put("file.ext", {:binary, <<42, 42, 42>>})
      {:ok, :created}
  """
  def put(%Config{} = config, path, content) do
    with {:ok, ref} <- do_put(config, path, content) do
      case :hackney.start_response(ref) do
        {:ok, 204, _, _} ->
          {:ok, :updated}

        {:ok, 201, _, _} ->
          {:ok, :created}

        error ->
          wrap_error(error)
      end
    else
      error ->
        wrap_error(error)
    end
  end

  @spec move(Config.t(), source :: String.t(), dest :: String.t(), overwrite :: boolean) ::
          {:ok, :moved} | {:error, atom}

  @doc """
  Moves a file on webdav server.

  If overwrite option (3rd argument) is set to false (true by default) will return {:error, :http_412}
  in case of destination file already exists.

  ### Examples

      MyClient.move("imag.png", "image.png")
      {:ok, :moved}
  """
  def move(%Config{base_url: base_url} = config, source_path, destination_path, overwrite) do
    dest_header = destination_header(base_url, destination_path)
    overwrite_header = overwrite_header(overwrite)

    case request(:move, source_path, [dest_header, overwrite_header], "", config) do
      {:ok, 204, _, _ref} ->
        {:ok, :moved}

      error ->
        wrap_error(error)
    end
  end

  @spec copy(Config.t(), source :: String.t(), dest :: String.t(), overwrite :: boolean) ::
          {:ok, :copied} | {:error, atom}

  @doc """
  Copies a file on webdav server. Refer to `move/4` for details.

  ### Examples
      MyClient.copy("image.png", "image_copy.png")
      {:ok, :copied}
  """
  def copy(%Config{base_url: base_url} = config, source_path, dest_path, overwrite) do
    dest_header = destination_header(base_url, dest_path)
    overwrite_header = overwrite_header(overwrite)

    case request(:copy, source_path, [dest_header, overwrite_header], "", config) do
      {:ok, 204, _, _ref} ->
        {:ok, :copied}

      error ->
        wrap_error(error)
    end
  end

  @spec delete(Config.t(), path :: String.t()) :: {:ok, :deleted} | {:error, atom}

  @doc """
  Deletes file or directory on webdav server.

  ### Examples

      MyClient.delete("file.png")
      {:ok, :deleted}
  """
  def delete(%Config{} = config, path) do
    case request(:delete, path, [], "", config) do
      {:ok, 204, _, _} ->
        {:ok, :deleted}

      error ->
        wrap_error(error)
    end
  end

  @spec mkcol(Config.t(), path :: String.t()) :: {:ok, :created} | {:error, atom}

  @doc """
  Creates a folder on wedav server.

  Note that webdav does not allow to create nested folders (HTTP 409 will be returned).
  Use `mkcol_recursive/2` to create nested directory structure.

  ### Examples

      MyClient.mkcol("foo")
      {:ok, :created}
  """
  def mkcol(%Config{} = config, path) do
    case request(:mkcol, path, [], "", config) do
      {:ok, 201, _, _} ->
        {:ok, :created}

      error ->
        wrap_error(error)
    end
  end

  @spec mkcol_recursive(Config.t(), path :: String.t()) :: {:ok, String.t()} | {:error, atom}
  @doc """
  Creates nested folders for given path or file.

  Performs sequential `mkcol/2` calls to populate nested structure.

  ### Examples
  Create structure for a file.
      MyClient.mkcol_recursive("foo/bar/baz/file.png")
      {:ok, :created}
  "foo", "foo/bar" and "foo/bar/baz" folders will be created.

  Create structure for a folder.
      MyClient.mkcol_recursive("foo/bar/")
      {:ok, :created}
  Note that trailing slash is required for directory paths.
  """
  def mkcol_recursive(%Config{} = config, path) do
    path
    |> Path.dirname()
    |> String.split("/")
    |> Enum.reduce_while({:ok, ""}, fn folder, {:ok, prefix} ->
      new_path = prefix <> "/" <> folder

      case mkcol(config, new_path) do
        {:ok, _} ->
          {:cont, {:ok, new_path}}

        error ->
          {:halt, error}
      end
    end)
  end

  defp do_put(config, path, {:file, file_path}) do
    case File.read(file_path) do
      {:ok, content} ->
        do_put(config, path, {:binary, content})

      error ->
        error
    end
  end

  defp do_put(config, path, {:binary, data}) do
    with {:ok, ref} <- request(:put, path, [], :stream, config),
         :ok <- :hackney.send_body(ref, data) do
      {:ok, ref}
    else
      error ->
        wrap_error(error)
    end
  end

  defp request(meth, url, headers, body, config) do
    started_at = now()
    full_url = full_url(config.base_url, url)
    headers = config.headers ++ headers

    case :hackney.request(meth, full_url, headers, body, config.hackney_options) do
      {:ok, status, _, _} = result ->
        log_request(meth, full_url, {:ok, status}, started_at)
        result

      result ->
        log_request(meth, full_url, result, started_at)
        result
    end
  end

  defp log_request(meth, url, result, started_at) do
    Logger.debug(fn ->
      meth = meth |> to_string |> String.upcase()
      "#{meth} #{url} completed with #{inspect(result)} in #{now() - started_at}ms"
    end)
  end

  defp now, do: :erlang.system_time(:millisecond)

  defp full_url(base_url, url) when is_binary(url), do: full_url(base_url, URI.parse(url))

  defp full_url(%URI{path: base_path} = base_url, %URI{} = uri) do
    base_url
    |> URI.merge(%{uri | path: Path.join(to_string(base_path), to_string(uri.path))})
    |> to_string
  end

  defp overwrite_header(true), do: {"Overwrite", "T"}
  defp overwrite_header(false), do: {"Overwrite", "F"}

  defp destination_header(base_url, url), do: {"Destination", full_url(base_url, url)}

  defp wrap_error({:ok, status, _headers}), do: {:error, String.to_atom("http_#{status}")}
  defp wrap_error({:ok, status, _headers, _ref}), do: {:error, String.to_atom("http_#{status}")}
  defp wrap_error({:error, reason}), do: {:error, reason}
end
