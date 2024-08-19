defmodule Dalet do
  def fetch_ghibli_films() do
    # Httpoison使ってAPIをcall
    {status, res} = HTTPoison.get("https://chokhmah.lol/dalet/api/single?populate=*")

    case status do
      :ok ->
        # ヘッダー読み込み
        # headers = res.headers
        # Enum.map(headers, fn {header, value} -> IO.puts("#{header}: #{value}\n") end)

        # bodyからデータ取得
        content =
          Map.get(res, :body)
          |> Jason.decode!()
          |> Map.get("data")
          |> Map.get("attributes")
          |> Map.get("content")

        IO.puts(content)

        System.get_env("anthropic_key", "none") |> IO.puts()
"""
        {:ok, response, request} =
          Anthropic.new()
          |> Anthropic.add_system_message("You are a helpful assistant")
          |> Anthropic.add_user_message("Explain monads in computer science. Be concise.")
          |> Anthropic.request_next_message()
          IO.puts(response)
          IO.puts(request)
"""
      :error ->
        :error
    end
  end
end
