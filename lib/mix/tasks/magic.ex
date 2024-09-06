defmodule Mix.Tasks.Magic do
  @moduledoc """
  魔法の処理を実行するための Mix タスク。

  使用方法:
    mix process_magic
  """
  use Mix.Task

  @shortdoc "魔法の処理を実行します"
  def run(_) do
    # アプリケーションを起動し、必要な依存関係を確実に読み込みます
    Application.ensure_all_started(:minamo)

    IO.puts("魔法の処理を開始します...")

    case MagicProcessor.process() do
      {:ok, spell, url} ->
        post_tweet(spell <> "\n" <> url)
        IO.puts("魔法の処理が正常に完了しました。")
      {:error, reason} ->
        IO.puts("エラーが発生しました: #{inspect(reason)}")
    end
  end

  defp post_tweet(text) do
    tweet_text = text

    case TwitterClient.post_tweet(tweet_text) do
      {:ok, response} ->
        IO.puts("Tweet posted successfully!")
        IO.puts("Tweet ID: #{response["data"]["id"]}")
        IO.puts("Tweet text: #{response["data"]["text"]}")

      {:error, reason} ->
        IO.puts("Failed to post tweet: #{reason}")
    end
  end
end
