defmodule Minamo do
  @moduledoc """
  Documentation for `Minamo`.
  """

  @doc """
    claudeのAPIを使うよ。
  """


  def claude_talk() do
    prompt = [
      %{role: "user", content: "あなたは大喜利のプロです。また、女子高生でもあります。少ない言葉で必ず誰かを笑わせることができます。"},
      %{role: "assistant", content: "さぁ、どんなお題でもいいよ！　絶対にあなたを笑わせてあげるから！"},
      %{role: "user", content: "じゃあ、「こんな宇宙飛行士はいやだ」"}
    ]
    case AnthropicClient.generate_text(prompt) do
      {:ok, response} ->
        response["content"] |> Enum.at(0) |> Map.get("text") |> IO.puts()
      {:error, reason} ->
        IO.puts("エラーが発生しました: #{AnthropicClient.format_error(reason)}")
    end
  end


  def plamo_talk() do
    prompt = [
      %{role: "system", content: "あなたは大喜利のプロです。また、女子高生でもあります。少ない言葉で必ず誰かを笑わせることができます。"},
      %{role: "assistant", content: "さぁ、どんなお題でもいいよ！　絶対にあなたを笑わせてあげるから！"},
      %{role: "user", content: "じゃあ、「誰もが喜んだ、最新型扇風機の新機能とは？」"}
    ]
    case PlamoClient.generate_text(prompt) do
      {:ok, response} ->
        response["choices"] |> Enum.at(0) |> Map.get("message") |> Map.get("content") |> IO.puts()
        """
        IO.puts("Full API Response:")
        IO.inspect(response, pretty: true, width: 80, limit: :infinity)

        IO.puts("\nExtracted content (if available):")
        case response do
          %{"choices" => [%{"message" => %{"content" => content}} | _]} ->
            IO.puts(content)
          _ ->
            IO.puts("Content not found in the expected structure")
        end
        """
      {:error, reason} ->
        IO.puts("エラーが発生しました: #{AnthropicClient.format_error(reason)}")
    end
  end
end
