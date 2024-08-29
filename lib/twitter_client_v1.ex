defmodule Minamo.TwitterClientV1 do
  use GenServer
  require Logger

  @base_url "https://api.twitter.com/1.1"

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  def get_mentions_timeline do
    GenServer.call(__MODULE__, :get_mentions_timeline)
  end

  def handle_call(:get_mentions_timeline, _from, state) do
    url = "#{@base_url}/statuses/mentions_timeline.json"
    params = [{"count", "20"}]  # 取得するツイート数を20に設定

    case make_request(:get, url, params) do
      {:ok, body} ->
        {:reply, {:ok, Jason.decode!(body)}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp make_request(method, url, params) do
    consumer_key = Application.get_env(:minamo, TwitterClientV1)[:consumer_key]
    consumer_secret = Application.get_env(:minamo, TwitterClientV1)[:consumer_key_secret]
    access_token = Application.get_env(:minamo, TwitterClientV1)[:access_token]
    access_token_secret = Application.get_env(:minamo, TwitterClientV1)[:access_token_secret]

    credentials = OAuther.credentials(
      consumer_key: consumer_key,
      consumer_secret: consumer_secret,
      token: access_token,
      token_secret: access_token_secret
    )

    {header, req_params} = OAuther.sign(to_string(method), url, params, credentials)

    url = if method == :get, do: url <> "?" <> URI.encode_query(req_params), else: url

    headers = [{"Authorization", header}]

    case HTTPoison.request(method, url, "", headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        {:ok, body}
      {:ok, %HTTPoison.Response{status_code: status_code, body: body}} ->
        Logger.error("Twitter API error: #{status_code}, #{body}")
        {:error, "HTTP Error: #{status_code}"}
      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("HTTP request failed: #{inspect(reason)}")
        {:error, "Network Error: #{reason}"}
    end
  end
end
