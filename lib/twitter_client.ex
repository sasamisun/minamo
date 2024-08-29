defmodule TwitterClient do
  @moduledoc """
  Twitter API クライアント
  OAuth 2.0 PKCE認証フローを使用し、トークンをStrapiで永続化します。
  """

  use GenServer
  require Logger

  @config Application.compile_env(:minamo, __MODULE__)

  # クライアント API

  @doc """
  TwitterClientのGenServerを起動します。
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  認証URLを生成します。
  """
  def generate_auth_url do
    GenServer.call(__MODULE__, :generate_auth_url)
  end

  @doc """
  認証コールバックを処理し、アクセストークンを取得します。
  """
  def handle_callback(code) do
    GenServer.call(__MODULE__, {:handle_callback, code})
  end

  @doc """
  指定されたテキストでツイートを投稿します。
  """
  def post_tweet(text) do
    GenServer.call(__MODULE__, {:post_tweet, text})
  end

  @doc """
  現在のアクセストークンとリフレッシュトークンを取得します。
  """
  def get_tokens do
    GenServer.call(__MODULE__, :get_tokens)
  end

  @doc """
  GenServerを正常に停止します。
  """
  def stop do
    GenServer.stop(__MODULE__, :normal)
  end

  @doc """
  ユーザーのメンションタイムラインを取得するぜ。
  """
  def get_mentions_timeline do
    GenServer.call(__MODULE__, :get_mentions_timeline)
  end

  # サーバーコールバック

  @impl true
  def init(:ok) do
    Process.flag(:trap_exit, true)
    {:ok, %{}}
  end

  @impl true
  def handle_call(:get_mentions_timeline, _from, state) do
    case get_valid_token() do
      {:ok, token} ->
        result = do_get_mentions_timeline(token)
        {:reply, result, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:generate_auth_url, _from, state) do
    {code_verifier, code_challenge} = generate_pkce_pair()
    state_value = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)

    query_params =
      URI.encode_query(%{
        "response_type" => "code",
        "client_id" => @config[:client_id],
        "redirect_uri" => @config[:redirect_uri],
        "scope" => @config[:scopes],
        "state" => state_value,
        "code_challenge" => code_challenge,
        "code_challenge_method" => "S256"
      })

    auth_url = "https://twitter.com/i/oauth2/authorize?#{query_params}"
    new_state = Map.put(state, :code_verifier, code_verifier)
    {:reply, auth_url, new_state}
  end

  @impl true
  def handle_call({:handle_callback, code}, _from, state) do
    case exchange_code_for_token(code, state.code_verifier) do
      {:ok, tokens} ->
        new_tokens = %{
          access_token: tokens["access_token"],
          refresh_token: tokens["refresh_token"],
          expires_at: calculate_expiry(tokens["expires_in"])
        }

        case StrapiClient.save_tokens(new_tokens) do
          {:ok, saved_tokens} ->
            Logger.info("Tokens saved to Strapi successfully")
            {:reply, {:ok, saved_tokens}, state}

          {:error, reason} ->
            Logger.error("Failed to save tokens to Strapi: #{inspect(reason)}")
            {:reply, {:error, "Failed to save tokens"}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:post_tweet, text}, _from, state) do
    case get_valid_token() do
      {:ok, token} ->
        result = do_post_tweet(text, token)
        {:reply, result, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:get_tokens, _from, state) do
    case StrapiClient.get_tokens() do
      {:ok, tokens} -> {:reply, tokens, state}
      {:error, reason} -> {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def terminate(_reason, _state) do
    Logger.info("TwitterClient terminating")
    :ok
  end


  # プライベート関数

  # 有効なアクセストークンを取得します。
  # 期限切れの場合は自動的にリフレッシュを試みます。
  defp get_valid_token do
    case StrapiClient.get_tokens() do
      {:ok, %{access_token: token, expires_at: expires_at, refresh_token: refresh_token}} ->
        case DateTime.from_iso8601(expires_at) do
          {:ok, expires_at_datetime, _offset} ->
            if DateTime.compare(expires_at_datetime, DateTime.utc_now()) == :gt do
              {:ok, token}
            else
              refresh_token(refresh_token)
            end
          {:error, _} ->
            refresh_token(refresh_token)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # リフレッシュトークンを使用して新しいアクセストークンを取得します。
  defp refresh_token(refresh_token) when is_binary(refresh_token) do
    case do_refresh_token(refresh_token) do
      {:ok, tokens} ->
        new_tokens = %{
          access_token: tokens["access_token"],
          refresh_token: tokens["refresh_token"] || refresh_token,
          expires_at: calculate_expiry(tokens["expires_in"])
        }

        case StrapiClient.save_tokens(new_tokens) do
          {:ok, saved_tokens} -> {:ok, saved_tokens.access_token}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp refresh_token(_), do: {:error, "No refresh token available"}

  # 実際にリフレッシュトークンを使用してAPIリクエストを行い、新しいトークンを取得します。
  defp do_refresh_token(refresh_token) do
    # Basic認証のヘッダーを作成
    auth_string = Base.encode64("#{@config[:client_id]}:#{@config[:client_secret]}")

    url = "https://api.twitter.com/2/oauth2/token"

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization", "Basic #{auth_string}"}
    ]

    body =
      URI.encode_query(%{
        "grant_type" => "refresh_token",
        "refresh_token" => refresh_token
      })

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("Failed to refresh token. Status: #{status_code}, Body: #{response_body}")
        {:error, "Failed to refresh token"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Network error while refreshing token: #{inspect(reason)}")
        {:error, "Network error"}
    end
  end

  # PKCE認証に必要なcode_verifierとcode_challengeのペアを生成します。
  defp generate_pkce_pair do
    code_verifier = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    code_challenge = :crypto.hash(:sha256, code_verifier) |> Base.url_encode64(padding: false)
    {code_verifier, code_challenge}
  end

  # 認証コードをアクセストークンと交換します。
  defp exchange_code_for_token(code, code_verifier) do
    url = "https://api.twitter.com/2/oauth2/token"

    # Basic認証のヘッダーを作成
    auth_string = Base.encode64("#{@config[:client_id]}:#{@config[:client_secret]}")

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization", "Basic #{auth_string}"}
    ]

    body =
      URI.encode_query(%{
        grant_type: "authorization_code",
        code: code,
        redirect_uri: @config[:redirect_uri],
        client_id: @config[:client_id],
        code_verifier: code_verifier
      })

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error(
          "Failed to exchange code for token. Status: #{status_code}, Body: #{response_body}"
        )

        {:error, "Failed to exchange code for token"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Network error while exchanging code for token: #{inspect(reason)}")
        {:error, "Network error"}
    end
  end

  # トークンの有効期限を計算します。
  defp calculate_expiry(expires_in) do
    DateTime.add(DateTime.utc_now(), expires_in, :second)
  end

  # 実際にツイートを投稿するAPIリクエストを行います。
  defp do_post_tweet(text, token) do
    url = "https://api.twitter.com/2/tweets"

    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    body = Jason.encode!(%{text: text})

    case HTTPoison.post(url, body, headers) do
      {:ok, %HTTPoison.Response{status_code: 201, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("Failed to post tweet. Status: #{status_code}, Body: #{response_body}")
        {:error, "HTTP Error: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("Network error while posting tweet: #{inspect(reason)}")
        {:error, "Network Error: #{reason}"}
    end
  end

  #メンションタイムラインを取得
  defp do_get_mentions_timeline(token) do
    url = "https://api.twitter.com/2/users/" <> @config[:twitter_id] <> "/mentions"
    headers = [
      {"Authorization", "Bearer #{token}"},
      {"Content-Type", "application/json"}
    ]

    case HTTPoison.get(url, headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code, body: response_body}} ->
        Logger.error("メンションタイムライン取得に失敗したぜ。ステータス: #{status_code}, ボディ: #{response_body}")
        {:error, "HTTPエラー: #{status_code}"}

      {:error, %HTTPoison.Error{reason: reason}} ->
        Logger.error("メンションタイムライン取得中にネットワークエラーが発生したぜ: #{inspect(reason)}")
        {:error, "ネットワークエラー: #{reason}"}
    end
  end
end
