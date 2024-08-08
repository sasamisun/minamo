defmodule Minamo do
  @moduledoc """
  Documentation for `Minamo`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Minamo.hello()
      :world

  """
  def hello do
    :world
    IO.puts("Hello world!")

  end

  def fetch_ghibli_films() do
    #Httpoison使ってAPIをcall
    {status, res} = HTTPoison.get("https://chokhmah.lol/dalet/api/single?populate=*")
    case status do
      :ok ->
        headers = res.headers
        Enum.map(headers, fn {header, value} -> IO.puts "#{header}: #{value}\n" end)

        #戻り値のbody(json)を解析
        #Poison.Parser.parse!(res.body)
          #|> Map.get("data")
          #|> Enum.map(&(&1["data"]["attributes"]["content"]))
          #|> IO.puts()
      :error -> :error
    end
end
end
