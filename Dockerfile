# Multi-stage Dockerfile for building a production release of the Phoenix app
# Notes:
# - Uses Elixir to compile the release and Node to build assets.
# - Adjust the Elixir and Node versions if your environment requires specific versions.

# 1) Build stage: compile the app and build assets
FROM elixir:1.15 AS build

# Install build tools and node (for tailwind/esbuild asset builds)
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates build-essential git unzip nodejs npm && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV=prod

# Install Hex + Rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy mix files and get deps first for better cache
COPY mix.exs mix.lock ./
COPY config ./config

RUN mix deps.get --only prod

# Copy the rest of the app
COPY . .

# Build assets and digest static files
# This project uses Tailwind and esbuild via Mix aliases. The alias `assets.deploy` runs the
# required steps. If your project requires a separate `assets/package.json`, ensure it exists.
RUN mix assets.deploy

# Compile and build a release
RUN mix release --overwrite


# 2) Runtime image: a small image which runs the release
FROM debian:bookworm-slim AS app

# System deps required at runtime (OpenSSL lib for crypto, etc)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libssl-dev openssl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the release from the build stage
COPY --from=build /app/_build/prod/rel/earth_scanner .

ENV HOME=/app
ENV LANG=C.UTF-8

# Default PORT (can be overridden by env at runtime)
ENV PORT=4000

EXPOSE 4000

# Docker-friendly entrypoint: run the release
CMD ["/app/bin/earth_scanner", "start"]
