defmodule MagicProcessor do
  @moduledoc """
  Strapiから魔法のレコードを処理し、新しいスペルを生成するモジュール。
  """

  require Logger

  @doc """
  処理を実行します。
  1. 最古の power=0 のレコードを取得
  2. コメントから新しいスペルを生成
  3. レコードを更新

  ## 返り値
    - `:ok` - 処理が成功した場合
    - `{:error, reason}` - エラーが発生した場合
  """
  def process do
    with {:ok, record} <- StrapiClient.get_oldest_zero_power_record(),
         {:ok, new_spell} <- text_generate(record["attributes"]["comment"]),
         {:ok, _updated_record} <- update_record(record["id"], new_spell) do
      {:ok, new_spell,record["attributes"]["url"]}
    else
      {:error, :no_records_found} ->
        Logger.info("処理すべきレコードが見つかりませんでした。")
        :ok
      {:error, reason} ->
        Logger.error("処理中にエラーが発生しました: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  与えられたコメントから新しいテキストを生成します。

  ## 引数
    - `comment` - 元のコメント

  ## 返り値
    - `{:ok, new_text}` - 生成成功時
    - `{:error, reason}` - 生成失敗時
  """
  def text_generate(comment) do
    new_text = AnthropicClient.create_spell(comment)
    {:ok, new_text}
  end

  @doc """
  指定されたIDのレコードを更新します。

  ## 引数
    - `id` - 更新するレコードのID
    - `new_spell` - 新しく生成されたスペル

  ## 返り値
    - `{:ok, updated_record}` - 更新成功時
    - `{:error, reason}` - 更新失敗時
  """
  def update_record(id, new_spell) do
    params = %{
      "spell" => new_spell,
      "power" => 1
    }
    StrapiClient.update_record(id, params)
  end
end
