defmodule Mix.Tasks.Minamo do
  @moduledoc "The hello mix task: `mix help hello`"
  use Mix.Task

  @shortdoc "Simply calls the Hello.say/0 function."
  def run(_) do
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:poison)
    Minamo.hello()
    Minamo.fetch_ghibli_films()
  end
end
