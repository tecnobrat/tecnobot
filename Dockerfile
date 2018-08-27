FROM elixir:1.7

RUN mix local.hex --force

RUN mkdir -p /app
WORKDIR /app
COPY mix.exs mix.lock /app/

RUN mix deps.get

COPY . /app

EXPOSE 4000
CMD iex -S mix
