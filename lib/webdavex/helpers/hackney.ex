defmodule Webdavex.Helpers.Hackney do
  @moduledoc "`:hackney` helpers."

  @spec stream_body(pid) :: Enumerable.t()
  @doc """
  Creates a `Stream` reader for :hackney response body.

  Refer to `:hackney.stream_body/1` for details.
  """
  def stream_body(ref) do
    Stream.resource(fn -> ref end, &read_chunk/1, &finish_read/1)
  end

  defp read_chunk(ref) do
    case :hackney.stream_body(ref) do
      {:ok, data} ->
        {[data], ref}

      :done ->
        {:halt, ref}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp finish_read(_), do: nil
end
