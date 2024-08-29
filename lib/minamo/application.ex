# lib/minamo/application.ex
defmodule Minamo.Application do
  alias Minamo.TwitterClientV1
  use Application

  def start(_type, _args) do
    children = [
      TwitterClientV1,
      TwitterClient
    ]

    opts = [strategy: :one_for_one, name: Minamo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    TwitterClient.stop()
  end

end
