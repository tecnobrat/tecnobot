defmodule TecnoBot.Bot do
  use GenServer
  require Logger

  defmodule Config do
    defstruct server:  nil,
              port:    nil,
              pass:    System.get_env("IRC_PASS"),
              nick:    nil,
              user:    nil,
              name:    nil,
              channel: nil,
              client:  nil

    def from_params(params) when is_map(params) do
      Enum.reduce(params, %Config{}, fn {k, v}, acc ->
        case Map.has_key?(acc, k) do
          true  -> Map.put(acc, k, v)
          false -> acc
        end
      end)
    end
  end

  alias ExIRC.Client
  alias ExIRC.SenderInfo

  def start_link(%{nick: nick} = params, client) when is_map(params) do
    config = Config.from_params(params)
    GenServer.start_link(__MODULE__, [config, client], name: String.to_atom(nick))
  end

  def init([config, client]) do
    # Register the event handler with ExIRC
    Client.add_handler client, self()

    # Connect and logon to a server, join a channel and send a simple message
    Logger.debug "Connecting to #{config.server}:#{config.port}"
    Client.connect! client, config.server, config.port

    {:ok, %Config{config | client: client}}
  end

  def handle_info({:connected, server, port}, config) do
    Logger.debug "Connected to #{server}:#{port}"
    Logger.debug "Logging to #{server}:#{port} as #{config.nick}.."
    Client.logon config.client, config.pass, config.nick, config.user, config.name
    {:noreply, config}
  end

  def handle_info(:logged_in, config) do
    Logger.debug "Logged in to #{config.server}:#{config.port}"
    Logger.debug "Joining #{config.channel}.."
    Client.join config.client, config.channel
    {:noreply, config}
  end

  def handle_info(:disconnected, config) do
    Logger.debug "Disconnected from #{config.server}:#{config.port}"
    {:stop, :normal, config}
  end

  def handle_info({:joined, channel}, config) do
    Logger.debug "Joined #{channel}"
    Client.msg config.client, :privmsg, config.channel, "Hi Chat, I'm here!  How can I help!"
    {:noreply, config}
  end

  def handle_info({:names_list, channel, names_list}, config) do
    names = String.split(names_list, " ", trim: true)
            |> Enum.map(fn name -> " #{name}\n" end)
    Logger.info "Users logged in to #{channel}:\n#{names}"
    {:noreply, config}
  end

  def handle_info({:received, "!" <> msg, %SenderInfo{nick: nick}, channel}, config) do
    try do
      reply = msg
              |> String.split(" ", parts: 2)
              |> call_command(nick)
      Logger.info "#{nick} from #{channel} ran a command '#{msg}'"

      Client.msg config.client, :privmsg, config.channel, reply
      {:noreply, config}
    catch
      :nocommand ->
        Logger.info "#{nick} from #{channel} ran an undefined command '#{msg}'"
        {:noreply, config}
    end
  end

  def call_command([command], nick) do
    call_command([command, nil], nick)
  end

  def call_command([command, args], nick) do
    cc_command = command |> Macro.camelize

    module = "Elixir.TecnoBot.Commands.#{cc_command}"
              |> String.to_atom

    try do
      apply(module, :handle, [args, nick])
    rescue
      UndefinedFunctionError -> throw(:nocommand)
    end
  end

  def handle_info({:received, msg, %SenderInfo{nick: nick}, channel}, config) do
    Logger.info "#{nick} from #{channel}: #{msg}"
    {:noreply, config}
  end

  def handle_info({:mentioned, msg, %SenderInfo{nick: nick}, channel}, config) do
    Logger.warn "#{nick} mentioned you in #{channel}"
    case String.contains?(msg, "hi") do
      true ->
        reply = "Hi #{nick}!"
        Client.msg config.client, :privmsg, config.channel, reply
        Logger.info "Sent #{reply} to #{config.channel}"
      false ->
        :ok
    end
    {:noreply, config}
  end

  def handle_info({:received, msg, %SenderInfo{nick: nick}}, config) do
    Logger.warn "#{nick}: #{msg}"
    reply = "Hi!"
    Client.msg config.client, :privmsg, nick, reply
    Logger.info "Sent #{reply} to #{nick}"
    {:noreply, config}
  end

  # Catch-all for messages you don't care about
  def handle_info(_msg, config) do
    {:noreply, config}
  end

  def terminate(_, state) do
    # Quit the channel and close the underlying client connection when the process is terminating
    Logger.debug "Received terminate, goodbye"
    Client.quit state.client, "Goodbye, cruel world."
    Client.stop! state.client
    :ok
  end
end
