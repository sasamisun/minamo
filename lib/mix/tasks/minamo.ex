defmodule Mix.Tasks.Minamo do
  @moduledoc "みなもtask: `mix help minamo`"
  use Mix.Task

  @shortdoc "access to claude"
  def run(_) do
    Mix.Task.run("app.start")
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:poison)
    # Minamo.claude_talk()
    # Minamo.start_conversation()
    AnthropicClient.create_spell("格闘ゲーム全然うまくならない。ライバルに勝ちたい！")
  end
end

defmodule Mix.Tasks.Minamo.Twitter do
  use Mix.Task

  @shortdoc "TwitterのAPIを使ってマスコットAIの操作をするぜ"
  def run(args) do
    Mix.Task.run("app.start")

    case args do
      ["-a"] ->
        authenticate()

      ["-d"] ->
        display_stored_tokens()

      ["-m"] ->
        display_mentions_timeline()

      [] ->
        post_tweet()

      _ ->
        IO.puts("無効な引数だぜ。認証は -a、トークン表示は -d、メンションタイムライン表示は -m を使ってくれ。引数なしだとツイート投稿になるぜ。")
    end
  end

  defp authenticate do
    auth_url = TwitterClient.generate_auth_url()
    IO.puts("Please visit the following URL to authorize the application:")
    IO.puts(auth_url)
    IO.puts("\nAfter authorization, you will be redirected to a callback URL.")
    IO.puts("Please enter the 'code' parameter from the callback URL:")

    code = IO.gets("") |> String.trim()

    case TwitterClient.handle_callback(code) do
      {:ok, tokens} ->
        IO.puts("Authentication successful!")
        IO.puts("Access Token: #{tokens.access_token}")
        IO.puts("Refresh Token: #{tokens.refresh_token}")

      {:error, reason} ->
        IO.puts("Authentication failed: #{reason}")
    end
  end

  defp post_tweet do
    tweet_text = "環境をちょっと変えてテスト投稿。"

    case TwitterClient.post_tweet(tweet_text) do
      {:ok, response} ->
        IO.puts("Tweet posted successfully!")
        IO.puts("Tweet ID: #{response["data"]["id"]}")
        IO.puts("Tweet text: #{response["data"]["text"]}")

      {:error, reason} ->
        IO.puts("Failed to post tweet: #{reason}")
    end
  end

  defp display_stored_tokens do
    case StrapiClient.get_tokens() do
      {:ok, tokens} ->
        IO.puts("[Stored Tokens]")
        IO.puts("Access Token: #{tokens.access_token || "Not available"}")
        IO.puts("Refresh Token: #{tokens.refresh_token || "Not available"}")

        case tokens.expires_at do
          nil -> IO.puts("Expiry: Not available")
          expires_at -> IO.puts("Expiry: #{expires_at}")
        end

      {:error, reason} ->
        IO.puts("Failed to retrieve tokens: #{reason}")
    end
  end

  defp display_mentions_timeline do
    case Minamo.TwitterClientV1.get_mentions_timeline() do
      {:ok, mentions} ->
        IO.puts("メンションタイムライン:")
        Enum.each(mentions, fn tweet ->
          IO.puts("ID: #{tweet["id_str"]}")
          IO.puts("ユーザー: @#{tweet["user"]["screen_name"]}")
          IO.puts("テキスト: #{tweet["text"]}")
          IO.puts("---")
        end)

      {:error, reason} ->
        IO.puts("メンションタイムラインの取得に失敗したぜ: #{reason}")
    end
  end
end
