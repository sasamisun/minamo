# lib/minamo/application.ex
defmodule Minamo.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false
    children = [
      TwitterClient,
      Minamo.Scheduler
    ]

    opts = [strategy: :one_for_one, name: Minamo.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def stop(_state) do
    TwitterClient.stop()
  end

end
