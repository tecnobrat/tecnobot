defmodule TecnoBot.Commands.Ping do
  def handle(nil, _nick) do
    "pong"
  end

  def handle(args, _nick) do
    "pong ... with ARRRRGS #{args}"
  end
end
