defmodule StrapiClient do
  @moduledoc """
  Strapiサーバーとの通信を管理するモジュール。
  会話履歴の保存や取得などの機能を提供します。
  """

  require Logger
  @config Application.compile_env(:minamo, __MODULE__, [])

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
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{@config[:strapi_key]}"}
    ]

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} when status_code in 200..299 ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("Failed to save message to Strapi. Status: #{status_code}, Body: #{response_body}")
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

    case HTTPoison.get(url) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        messages = Jason.decode!(body)["data"]
        |> Enum.map(fn item ->
          %{
            role: item["attributes"]["role"],
            content: item["attributes"]["content"]
          }
        end)
        {:ok, Enum.reverse(messages)}
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Failed to get history from Strapi. Status: #{status_code}, Body: #{body}")
        {:error, "Failed to get history. Status: #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request to Strapi failed: #{inspect(reason)}")
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end
end
