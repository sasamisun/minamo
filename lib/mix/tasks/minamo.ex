defmodule Mix.Tasks.Minamo do
  @moduledoc "みなもtask: `mix help minamo`"
  use Mix.Task

  @shortdoc "access to claude"
  def run(_) do
    Mix.Task.run("app.start")
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:poison)
    #Minamo.claude_talk()
    Minamo.plamo_talk()
  end
end
