defmodule AnthropicClient do
  @moduledoc """
  Anthropic API クライアント

  このモジュールは Anthropic API との通信を管理し、テキスト生成機能を提供します。
  """

  @config Application.compile_env(:minamo, __MODULE__, [])

  @doc """
  Anthropic API を使用してテキストを生成します。

  ## パラメータ
    - prompt: 生成の基となるプロンプト文字列
    - opts: オプションのキーワードリスト
      - :model - 使用するモデル (デフォルト: config.exs で指定)
      - :max_tokens - 生成するトークンの最大数 (デフォルト: config.exs で指定)
      - :temperature - 出力の多様性を制御 (デフォルト: config.exs で指定)
      - :top_p - 核サンプリングのしきい値 (デフォルト: config.exs で指定)
      - :top_k - 考慮するトークンの最大数 (デフォルト: config.exs で指定)

  ## 戻り値
    - {:ok, response} - 成功時。response は API からの応答
    - {:error, reason} - エラー時
  """
  def generate_text(prompt, opts \\ []) do
    model = Keyword.get(opts, :model, @config[:default_model])
    max_tokens = Keyword.get(opts, :max_tokens, @config[:max_tokens])
    temperature = Keyword.get(opts, :temperature, @config[:temperature])
    top_p = Keyword.get(opts, :top_p, @config[:top_p])
    top_k = Keyword.get(opts, :top_k, @config[:top_k])

    body =
      %{
        model: model,
        messages: prompt,
        max_tokens: max_tokens,
        temperature: temperature
      }
      |> add_if_present(:top_p, top_p)
      |> add_if_present(:top_k, top_k)
      |> Jason.encode!()

    url = @config[:base_url] <> "/messages"

    headers = [
      {"Content-Type", "application/json"},
      {"X-API-Key", @config[:api_key]},
      {"anthropic-version", @config[:api_version]}
    ]

    IO.puts(url)
    # IO.puts(headers)

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

  defp add_if_present(map, _key, nil), do: map
  defp add_if_present(map, key, value), do: Map.put(map, key, value)

  @doc """
  エラーレスポンスを人間が読みやすい形式に整形します。
  """
  def format_error({status_code, %{"error" => error}}) do
    "HTTP #{status_code}: #{error["type"]} - #{error["message"]}"
  end

  def format_error(reason) when is_binary(reason), do: reason
  def format_error(reason), do: inspect(reason)
end
