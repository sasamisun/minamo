defmodule Minamo do
  @moduledoc """
  Documentation for `Minamo`.
  """
  use Application

  @config Application.compile_env(:minamo, __MODULE__, [])

  def start(_type, _args) do
    children = [
      # This is the new line
      Minamo.Scheduler
    ]

    opts = [strategy: :one_for_one, name: Minamo.Supervisor]
    Supervisor.start_link(children, opts)
  end

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

  @doc """
  無限ループでplamo_talk/0を呼び出し、継続的な対話を行います。
  ユーザーが "quit" または "exit" と入力すると会話を終了します。
  """
  def start_conversation do
    display_conversation_history()
    IO.puts("会話を開始します。終了するには 'quit' または 'exit' と入力してください。")
    do_conversation()
  end
  #履歴10件表示
  defp display_conversation_history do
    case StrapiClient.get_history(10) do
      {:ok, history} ->
        IO.puts("過去の会話履歴（最新10件）:")
        Enum.each(history, fn message ->
          role = if message.role == "user", do: "you", else: "minamo"
          IO.puts("[#{role}] #{message.content}")
          IO.puts("------------------------------------")
        end)
      {:error} ->
        IO.puts("会話履歴の取得に失敗しました。")
    end
  end
  #トークループ
  defp do_conversation do
    IO.puts("[you]?")
    user_input = IO.gets("")
    |> :unicode.characters_to_binary(:utf8)
    |> String.trim()

    case String.downcase(user_input) do
      "quit" ->
        IO.puts("会話を終了します。ありがとうございました。")

      "exit" ->
        IO.puts("会話を終了します。ありがとうございました。")

      _ ->
        plamo_talk(user_input)
        do_conversation()
    end
  end

  @doc """
    plamoのAPIを使うよ。
  """
  def plamo_talk(user_input) do
    prompt = create_senddata_plamo()

    message = %{role: "user", content: user_input}
    # 保存
    case StrapiClient.save_message(message) do
      {:ok} ->
        IO.puts("------------------------------------")

      {:error, reason} ->
        IO.puts("----------Failed to save message: #{reason}")
    end

    # 次のトーク内容をpromptに追加
    newPrompt = prompt ++ [message]

    # IO.inspect(newPrompt, pretty: true, width: 80, limit: :infinity)
    # 返事を受け取る
    case PlamoClient.generate_text(newPrompt) do
      {:ok, response} ->
        message =
          response["choices"]
          |> Enum.at(0)
          |> Map.get("message")
          |> Map.get("content")
          |> remove_comment()

        # 表示
        IO.puts("[minamo]")
        IO.puts(message)
        # 保存
        assistant_message = %{role: "assistant", content: message}

        case StrapiClient.save_message(assistant_message) do
          {:ok} ->
            IO.puts("------------------------------------")

          {:error, reason} ->
            IO.puts("----------Failed to save message: #{reason}")
        end

      {:error, reason} ->
        IO.puts("エラーが発生しました: #{AnthropicClient.format_error(reason)}")
    end
  end

  #  plamoのAPIを使うときのリクエストデータを作成するよ
  defp create_senddata_plamo() do
    # Strapiからシステムプロンプトを取得
    system_content =
      case StrapiClient.get_prompt(1) do
        {:ok, content} ->
          content

        {:error, _reason} ->
          # IO.puts("システムメッセージの取得に失敗しました。デフォルトの値を使用します。")
          @config[:default_system_prompt]
      end

    system_message = %{role: "system", content: system_content}

    # Strapiから履歴を取得
    # 最新の5件を取得
    case StrapiClient.get_history(5) do
      {:ok, history} ->
        [system_message | history]

      {:error} ->
        [system_message]
    end
  end

  #  plamoから来たメッセージの最後についてくるコメントを削除するよ。
  #  改行　改行　（コメント）
  defp remove_comment(text) do
    text
    |> String.replace(~r/\n\n\（.*?\）$/, "")
    |> String.trim()
  end
end

"""
#これはメモです。以下の内容は無視してください。
#レスポンスの内容全表示
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
