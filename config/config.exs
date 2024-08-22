import Config

# パラメータの説明:
#
# temperature（温度）:
# 範囲: 通常0.0から1.0（時に2.0まで）
# 効果: 出力の多様性や「創造性」を制御します
# 低い値（0.0に近い）: より予測可能で一貫性のある出力
# 高い値（1.0に近い）: より多様で予想外の出力
# 使用例: 事実に基づく回答には低い値、創造的な文章には高い値
#
# top_p（核サンプリング）:
# 範囲: 0.0から1.0
# 効果: 次のトークンを選ぶ際の候補を制限します
# 動作: 累積確率がtop_pを超えるまで、最も可能性の高いトークンを選択します
# 低い値: より焦点の絞られた、予測可能な出力
# 高い値: より多様な出力
# 注意: temperatureとの併用は通常推奨されません
#
# top_k:
# 範囲: 正の整数（例：1から100）
# 効果: 次のトークンの選択肢を上位k個に制限します
# 低い値: より一貫性のある、ときに反復的な出力
# 高い値: より多様な出力、ただし低品質なオプションも含む可能性あり
config :minamo, AnthropicClient,
  base_url: "https://api.anthropic.com/v1",
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  default_model: "claude-3-haiku-20240307",
  api_version: "2023-06-01",
  max_tokens: 1000,
  temperature: 0.7,
  top_p: 0.9,
  top_k: 5

config :minamo, PlamoClient,
  base_url: "https://platform.preferredai.jp",
  api_key: System.get_env("PLAMO_API_KEY"),
  default_model: "plamo-beta"

config :minamo, StrapiClient,
  strapi_url: "https://chokhmah.lol/dalet/api",
  strapi_key: System.get_env("STRAPI_KEY"),
  default_system_prompt: "あなたは記憶のデータ取得に失敗したAIアシスタントです。何を聞かれてもエラーが起こった旨を50文字以内で伝えてください。"
