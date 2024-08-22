defmodule PlamoClient do
  @moduledoc """
  Plamo API クライアント

  このモジュールは Plamo API との通信を管理し、テキスト生成機能を提供します。
  """

  @config Application.compile_env(:minamo, __MODULE__, [])

  @doc """
  Plamo API を使用してテキストを生成します。

  ## パラメータ
    - prompt: 生成の基となるプロンプト文字列
    - opts: オプションのキーワードリスト
      - :model - 使用するモデル (デフォルト: config.exs で指定)

  ## 戻り値
    - {:ok, response} - 成功時。response は API からの応答
    - {:error, reason} - エラー時
  """
  def generate_text(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, @config[:default_model])

    body =
      %{
        model: model,
        messages: prompt
      }
      |> Jason.encode!()

    url = @config[:base_url] <> "/api/completion/v1/chat/completions"

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{@config[:api_key]}"}
    ]

    # タイムアウト設定を追加
    timeout_options = [
      # リクエスト全体のタイムアウト（ミリ秒）
      timeout: 60_000,
      # レスポンス受信のタイムアウト（ミリ秒）
      recv_timeout: 55_000
    ]

    case HTTPoison.post(url, body, headers, timeout_options) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        {:error, {status_code, Jason.decode!(response_body)}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @doc """
  エラーレスポンスを人間が読みやすい形式に整形します。
  """
  def format_error({status_code, %{"error" => error}}) do
    "HTTP #{status_code}: #{error["type"]} - #{error["message"]}"
  end
  def format_error(reason) when is_binary(reason), do: reason
  def format_error(reason), do: inspect(reason)
end
