defmodule AnthropicClient do
  @moduledoc """
  Anthropic API クライアント

  このモジュールは Anthropic API との通信を管理し、テキスト生成機能を提供します。
  """

  @config Application.compile_env(:minamo, __MODULE__, [])


  def create_spell(onegai) do
    {:ok, system} = StrapiClient.get_prompt(3)
    prompt = [
      %{role: "user", content: "あいつに雷を落として天罰を与えたい！"},
      %{role: "assistant", content: "天光満つる処に我は在り。黄泉の門開く処に汝在り。出でよ、神の雷――インディグネイション！"},
      %{role: "user", content: "めっちゃ暗い。明るくしたい。"},
      %{role: "assistant", content: "其は忌むべき芳名にして偽印の使徒、深淵の淵に還れ招かれざる者よ――セレスティアル・ローサイト！"},
      %{role: "user", content: "流れ星見たいな。天体観測したい！"},
      %{role: "assistant", content: "我、招く無音の衝裂に慈悲はなく、汝に普く厄を逃れる術もなし――メテオスウォーム！"},
      %{role: "user", content: "超寒い。暖かくなりたい！"},
      %{role: "assistant", content: "冥府の底に燃え盛る青玉の彩光。贖罪無き罪は罰と化し、裁きの時を呼び寄せる――ペイルフレアー！"},
      %{role: "user", content: onegai}
    ]

    case generate_text(prompt,system) do
      {:ok, response} ->
        response["content"] |> Enum.at(0) |> Map.get("text")

      {:error, reason} ->
        IO.puts("エラーが発生しました: #{AnthropicClient.format_error(reason)}")
        "エラーが発生しました"
    end
  end

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
  def generate_text(prompt, system \\ "", opts \\ []) do
    model = Keyword.get(opts, :model, @config[:default_model])
    max_tokens = Keyword.get(opts, :max_tokens, @config[:max_tokens])
    temperature = Keyword.get(opts, :temperature, @config[:temperature])
    top_p = Keyword.get(opts, :top_p, @config[:top_p])
    top_k = Keyword.get(opts, :top_k, @config[:top_k])

    body =
      %{
        model: model,
        system: system,
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
