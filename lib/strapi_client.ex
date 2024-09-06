defmodule StrapiClient do
  @moduledoc """
  Strapiサーバーとの通信を管理するモジュール。
  会話履歴の保存や取得などの機能を提供します。
  """

  require Logger
  @config Application.compile_env(:minamo, __MODULE__, [])

  # 共通ヘッダ
  defp headers do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{@config[:strapi_key]}"}
    ]
  end

  @doc """
  会話のメッセージをStrapiに保存します。

  ## パラメータ
    - message: 保存するメッセージ（%{role: string, content: string}の形式）

  ## 戻り値
    - {:ok, response} - 成功時。responseはStrapiからの応答
    - {:error, reason} - エラー時
  """
  def save_message(message) do
    url = @config[:strapi_url] <> "/minamo-histories"
    body = Jason.encode!(%{data: message})

    case HTTPoison.post(url, body, headers()) do
      {:ok, %HTTPoison.Response{status_code: status_code}} when status_code in 200..299 ->
        {:ok}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error(
          "Failed to save message to Strapi. Status: #{status_code}, Body: #{response_body}"
        )

        {:error, "Failed to save message. Status: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request to Strapi failed: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Strapiから会話履歴を取得します。

  ## パラメータ
    - limit: 取得するメッセージの最大数（オプション、デフォルトは10）

  ## 戻り値
    - {:ok, messages} - 成功時。messagesは取得したメッセージのリスト
    - {:error, reason} - エラー時
  """
  def get_history(limit \\ 10) do
    query_params = "?sort=createdAt:desc&pagination[limit]=#{limit}"
    url = @config[:strapi_url] <> "/minamo-histories" <> query_params

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        messages =
          Jason.decode!(body)["data"]
          |> Enum.map(fn item ->
            %{
              role: item["attributes"]["role"],
              content: item["attributes"]["content"]
            }
          end)

        {:ok, Enum.reverse(messages)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Failed to get history from Strapi. Status: #{status_code}, Body: #{body}")
        {:error}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request to Strapi failed: #{inspect(reason)}")
        {:error}
    end
  end

  @doc """
  Strapiから特定のIDのプロンプトを取得します。

  ## パラメータ
    - id: 取得するプロンプトのID

  ## 戻り値
    - {:ok, prompt} - 成功時。promptは取得したプロンプトの内容
    - {:error, reason} - エラー時
  """
  def get_prompt(id) do
    url = @config[:strapi_url] <> "/minamo-prompts/#{id}"

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        data = Jason.decode!(body)
        prompt = data["data"]["attributes"]["value"]
        {:ok, prompt}

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Failed to get prompt from Strapi. Status: #{status_code}, Body: #{body}")
        {:error, "Failed to get prompt. Status: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request to Strapi failed: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  StrapiからTwitter認証トークンを取得します。

  ## 戻り値
    - {:ok, tokens} - 成功時。tokensはアクセストークン、リフレッシュトークン、有効期限を含むマップ
    - {:error, reason} - エラー時
  """
  def get_tokens do
    url = @config[:strapi_url] <> "/minamo-twitter-token"

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        data = Jason.decode!(body)["data"]

        if data do
          {:ok,
           %{
             access_token: data["attributes"]["access_token"],
             refresh_token: data["attributes"]["refresh_token"],
             expires_at: data["attributes"]["expires_at"]
           }}
        else
          {:error, "No tokens found"}
        end

      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Failed to get tokens from Strapi. Status: #{status_code}, Body: #{body}")
        {:error, "Failed to get tokens. Status: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request to Strapi failed: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Twitter認証トークンをStrapiに保存します。

  ## パラメータ
    - tokens: 保存するトークン（%{access_token: string, refresh_token: string, expires_at: DateTime.t()}の形式）

  ## 戻り値
    - {:ok, saved_tokens} - 成功時。saved_tokensは保存されたトークン情報
    - {:error, reason} - エラー時
  """
  def save_tokens(tokens) do
    url = @config[:strapi_url] <> "/minamo-twitter-token"

    body =
      Jason.encode!(%{
        data: %{
          access_token: tokens.access_token,
          refresh_token: tokens.refresh_token,
          expires_at: tokens.expires_at
        }
      })

    case HTTPoison.put(url, body, headers()) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}}
      when status_code in 200..299 ->
        saved_data = Jason.decode!(response_body)["data"]

        {:ok,
         %{
           access_token: saved_data["attributes"]["access_token"],
           refresh_token: saved_data["attributes"]["refresh_token"],
           expires_at: saved_data["attributes"]["expires_at"]
         }}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error(
          "Failed to save tokens to Strapi. Status: #{status_code}, Body: #{response_body}"
        )

        {:error, "Failed to save tokens. Status: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request to Strapi failed: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  powerが0で最古のレコードを取得します。

  ## 返り値
    - `{:ok, record}` - 成功時。recordは取得したレコード。
    - `{:error, reason}` - エラー時。reasonはエラーの理由。
  """
  def get_oldest_zero_power_record do
    url =
      @config[:strapi_url] <>
        "/minamo-magics?sort=createdAt:asc&filters[power][$eq]=0&pagination[pageSize]=1"

    case HTTPoison.get(url, headers()) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        data = Jason.decode!(body)

        case data["data"] do
          [record | _] -> {:ok, record}
          [] -> {:error, :no_records_found}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Failed to get oldest zero power record. Status: #{status_code}")
        {:error, "HTTP error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end

  @doc """
  指定されたIDのレコードを更新します。

  ## 引数
    - `id` - 更新するレコードのID
    - `params` - 更新するパラメータのマップ

  ## 返り値
    - `{:ok, updated_record}` - 成功時。updated_recordは更新後のレコード。
    - `{:error, reason}` - エラー時。reasonはエラーの理由。
  """
  def update_record(id, params) do
    url = @config[:strapi_url] <> "/minamo-magics/#{id}"
    body = Jason.encode!(%{data: params})

    case HTTPoison.put(url, body, headers()) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}}
      when status_code in 200..299 ->
        updated_record = Jason.decode!(response_body)["data"]
        {:ok, updated_record}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Failed to update record. Status: #{status_code}")
        {:error, "HTTP error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Network error: #{inspect(reason)}"}
    end
  end
end
