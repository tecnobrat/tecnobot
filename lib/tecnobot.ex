defmodule TecnoBot do
  use Application
  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    {:ok, client}  = ExIRC.start_client!

    children = [worker(TecnoBot.Bot, [Application.get_env(:tecnobot, :bot), client])]

    opts = [strategy: :one_for_one, name: TecnoBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
