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

# Ensure dependencies are up-to-date and compiled before building assets. Some git/option
# changes (e.g. heroicons sparse options) can make the lockfile outdated inside the build
# environment; forcing deps.get and compiling here updates the lock and avoids the
# "lock is outdated" error during `mix assets.deploy`.
RUN mix deps.get --force && mix deps.compile --force && mix compile

# If Phoenix LiveView colocated JS was emitted into the build path ("_build/prod/phoenix-colocated"),
# make it available to the JS bundler by copying it into `assets/node_modules/phoenix-colocated`.
# This mirrors what a local dev environment does (where phoenix-colocated is symlinked into node_modules).
RUN if [ -d _build/prod/phoenix-colocated ]; then \
            mkdir -p assets/node_modules/phoenix-colocated && \
            cp -r _build/prod/phoenix-colocated/* assets/node_modules/phoenix-colocated/; \
        fi

# Build assets and digest static files
# This project uses Tailwind and esbuild via Mix aliases. The alias `assets.deploy` runs the
# required steps. If your project requires a separate `assets/package.json`, ensure it exists.
RUN mix assets.deploy

# Compile and build a release
RUN mix release --overwrite


# 2) Runtime image: a small image which runs the release
FROM debian:bookworm-slim AS app

# System deps required at runtime (OpenSSL lib for crypto, etc)
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates libssl-dev openssl postgresql-client && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the release from the build stage
COPY --from=build /app/_build/prod/rel/earth_scanner .

# Copy entrypoint script (wait-for-db + migrate + start)
COPY docker-entrypoint.sh /app/bin/entrypoint.sh
RUN chmod +x /app/bin/entrypoint.sh

ENV HOME=/app
ENV LANG=C.UTF-8

# Default PORT (can be overridden by env at runtime)
ENV PORT=4000

EXPOSE 4000

# Use the entrypoint to wait for the DB, run migrations, then start the release
ENTRYPOINT ["/app/bin/entrypoint.sh"]
