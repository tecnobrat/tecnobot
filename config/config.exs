use Mix.Config

config :tecnobot,
  bot: %{server: "irc.chat.twitch.tv", port: 6667,
    nick: "tecnob0t", user: "tecnobot", name: "tecnobot",
    channel: "#tecnobrat"}

import_config "#{Mix.env}.exs"
