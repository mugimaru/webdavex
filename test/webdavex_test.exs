defmodule WebdavexTest do
  use ExUnit.Case, async: false
  doctest Webdavex.Config

  alias Plug.Conn

  @image_path Path.join(["test", "support", "fixtures", "img.png"]) |> Path.absname()
  @image_content File.read!(@image_path)

  defmodule Klient do
    use Webdavex.Agent, base_url: "http://localhost"
  end

  setup do
    bypass = Bypass.open()
    {:ok, _pid} = Klient.start_link(base_url: "http://localhost:#{bypass.port}/dav", headers: [{"foo", "bar"}])
    {:ok, bypass: bypass}
  end

  defmodule RequestsTracer do
    @moduledoc "Traces sequential requests order"
    use Agent

    @spec start_link(list(String.t())) :: {:ok, pid}
    def start_link(requests) do
      Agent.start_link(fn -> requests end)
    end

    @spec requests(pid) :: list(String.t())
    def requests(pid) do
      Agent.get(pid, fn r -> r end)
    end

    @spec notify_requested(pid, String.t()) :: list(String.t())
    def notify_requested(pid, path) do
      Agent.get_and_update(pid, fn [expected_path | rest_paths] = prev_state ->
        assert path == expected_path
        {prev_state, rest_paths}
      end)
    end
  end

  defp assert_adds_default_header(conn) do
    %{headers: [{k, v}]} = Klient.config()
    assert_header(conn.req_headers, k, v)
  end

  defp assert_header(headers, key, value) do
    header = Enum.find(headers, fn {k, _v} -> k == key end)
    assert {key, value} == header
  end

  test "config/0 returns configuration struct", %{bypass: bypass} do
    assert Klient.config() == %Webdavex.Config{
             base_url: URI.parse("http://localhost:#{bypass.port}/dav"),
             hackney_options: [],
             headers: [{"foo", "bar"}]
           }
  end

  describe "put/1" do
    test "sends PUT request for a new file", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/dav/images/img.png", fn conn ->
        assert_adds_default_header(conn)

        {:ok, body, conn} = Conn.read_body(conn)
        assert @image_content == body

        Conn.resp(conn, 201, "")
      end)

      assert {:ok, :created} == Klient.put("images/img.png", {:file, @image_path})
    end

    test "returns an error if file does not exist" do
      assert {:error, :enoent} == Klient.put("images/img.png", {:file, Path.absname("foobar.png")})
    end

    test "sends PUT request for existing file", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/dav/images/img.png", fn conn ->
        assert_adds_default_header(conn)

        {:ok, body, conn} = Conn.read_body(conn)
        assert @image_content == body

        Conn.resp(conn, 204, "")
      end)

      assert {:ok, :updated} == Klient.put("images/img.png", {:file, @image_path})
    end

    test "sends PUT request for binary content", %{bypass: bypass} do
      Bypass.expect_once(bypass, "PUT", "/dav/images/img.png", fn conn ->
        assert_adds_default_header(conn)

        {:ok, body, conn} = Conn.read_body(conn)
        assert @image_content == body

        Conn.resp(conn, 204, "")
      end)

      assert {:ok, :updated} == Klient.put("images/img.png", {:binary, @image_content})
    end
  end

  describe "head/1" do
    test "returns response headers", %{bypass: bypass} do
      Bypass.expect_once(bypass, "HEAD", "/dav/images/img.png", fn conn ->
        assert_adds_default_header(conn)

        conn
        |> Conn.put_resp_header("Foo-Bar", "baz")
        |> Conn.resp(200, "")
      end)

      assert {:ok, headers} = Klient.head("images/img.png")
      assert {"Foo-Bar", "baz"} == Enum.find(headers, fn {k, _v} -> k == "Foo-Bar" end)
    end
  end

  describe "get/1" do
    test "loads file content", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/dav/images/img.png", fn conn ->
        assert_adds_default_header(conn)
        Conn.send_file(conn, 200, @image_path)
      end)

      assert {:ok, content} = Klient.get("images/img.png")
      assert content == @image_content
    end
  end

  describe "copy/2" do
    test "sends COPY request with default overwrite option value (true)", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "COPY"
        assert conn.request_path == "/dav/images/img.png"
        assert_header(conn.req_headers, "overwrite", "T")
        assert_header(conn.req_headers, "destination", "#{Klient.config().base_url}/images/img_copy.png")
        assert_adds_default_header(conn)

        Conn.resp(conn, 204, "")
      end)

      assert {:ok, :copied} == Klient.copy("images/img.png", "images/img_copy.png")
    end

    test "sends COPY request with overwrite=false", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "COPY"
        assert conn.request_path == "/dav/images/img.png"
        assert_header(conn.req_headers, "overwrite", "F")
        assert_header(conn.req_headers, "destination", "#{Klient.config().base_url}/images/img_copy.png")
        assert_adds_default_header(conn)

        Conn.resp(conn, 204, "")
      end)

      assert {:ok, :copied} == Klient.copy("images/img.png", "images/img_copy.png", false)
    end
  end

  describe "move/2" do
    test "sends MOVE request with default overwrite option value (true)", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "MOVE"
        assert conn.request_path == "/dav/images/img.png"
        assert_header(conn.req_headers, "overwrite", "T")
        assert_header(conn.req_headers, "destination", "http://localhost:#{bypass.port}/dav/images/img_copy.png")
        assert_adds_default_header(conn)

        Conn.resp(conn, 204, "")
      end)

      assert {:ok, :moved} == Klient.move("images/img.png", "images/img_copy.png")
    end

    test "sends MOVE request with overwrite=false", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "MOVE"
        assert conn.request_path == "/dav/images/img.png"
        assert_header(conn.req_headers, "overwrite", "F")
        assert_header(conn.req_headers, "destination", "http://localhost:#{bypass.port}/dav/images/img_copy.png")
        assert_adds_default_header(conn)

        Conn.resp(conn, 204, "")
      end)

      assert {:ok, :moved} == Klient.move("images/img.png", "images/img_copy.png", false)
    end
  end

  describe "delete/1" do
    test "sends DELETE request", %{bypass: bypass} do
      Bypass.expect_once(bypass, "DELETE", "/dav/images/img.png", fn conn ->
        assert_adds_default_header(conn)
        Conn.send_file(conn, 204, @image_path)
      end)

      assert {:ok, :deleted} = Klient.delete("images/img.png")
    end
  end

  describe "mkcol_recursive/1" do
    test "sends multiple MKCOL requests for file", %{bypass: bypass} do
      {:ok, tracer_pid} = RequestsTracer.start_link(["/dav/images", "/dav/images/foo"])

      Bypass.expect(bypass, fn conn ->
        assert conn.method == "MKCOL"
        RequestsTracer.notify_requested(tracer_pid, conn.request_path)

        assert_adds_default_header(conn)
        Conn.resp(conn, 201, "")
      end)

      assert {:ok, "/images/foo"} == Klient.mkcol_recursive("images/foo/bar.png")
      assert RequestsTracer.requests(tracer_pid) == []
    end

    test "halts after first failure and returns its result", %{bypass: bypass} do
      Bypass.expect(bypass, fn conn ->
        assert conn.method == "MKCOL"

        case conn.request_path do
          "/dav/images" ->
            Conn.resp(conn, 201, "")

          "/dav/images/foo" ->
            Conn.resp(conn, 500, "")

          path ->
            raise(RuntimeError, "It is expected that #{path} wont be requested.")
        end
      end)

      assert {:error, :http_500} == Klient.mkcol_recursive("images/foo/bar/baz/qux/")
    end

    test "sends multiple MKCOL requests for folder", %{bypass: bypass} do
      {:ok, tracer_pid} = RequestsTracer.start_link(["/dav/images", "/dav/images/foo", "/dav/images/foo/bar"])

      Bypass.expect(bypass, fn conn ->
        assert conn.method == "MKCOL"
        RequestsTracer.notify_requested(tracer_pid, conn.request_path)

        assert_adds_default_header(conn)
        Conn.resp(conn, 201, "")
      end)

      assert {:ok, "/images/foo/bar"} == Klient.mkcol_recursive("images/foo/bar/")
      assert RequestsTracer.requests(tracer_pid) == []
    end
  end

  describe "mkcol/1" do
    test "sends MKCOL request", %{bypass: bypass} do
      Bypass.expect_once(bypass, fn conn ->
        assert conn.method == "MKCOL"
        assert conn.request_path == "/dav/images"

        assert_adds_default_header(conn)
        Conn.resp(conn, 201, "")
      end)

      assert {:ok, :created} == Klient.mkcol("images")
    end
  end
end
