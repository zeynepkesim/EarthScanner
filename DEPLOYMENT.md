Deployment notes
==============

This document explains how to build and run the Phoenix app using Docker.

Build (production release)
---------------------------

1. Build the image (from project root):

```bash
docker build -t earth_scanner:latest .
```

2. Generate a secret and set required env vars before running container:

```bash
# generate a secret locally
mix phx.gen.secret

# then run container providing SECRET_KEY_BASE and DATABASE_URL
docker run -e SECRET_KEY_BASE=your_secret -e DATABASE_URL="ecto://postgres:postgres@db/earth_scanner_prod" -p 4000:4000 earth_scanner:latest
```

Using docker-compose (local dev/testing)
---------------------------------------

The provided `docker-compose.yml` includes a `db` (Postgres) and `mailhog` service for testing emails. To bring up services:

```bash
docker compose up --build
```

Notes / Caveats
---------------

- The Dockerfile tries to run `mix assets.deploy` and `mix release`. If your project requires a separate `assets/package.json` or extra Node toolset, ensure `assets/package.json` exists and any Node dependencies are present.
- Ensure `SECRET_KEY_BASE` is set in your environment or via `docker-compose.override.yml` before starting in production.
- Running DB migrations: after the image is built you can run migrations inside the container with:

```bash
docker compose run --rm app /app/bin/earth_scanner eval "Erleton.Release.migrate"
```

Replace the migrate command above with your app's migrate helper if different.

If you want, I can:
- Tweak the `Dockerfile` to use a specific Elixir/OTP base image tag
- Add a `healthcheck` and a small entrypoint script that runs migrations automatically
- Add a `docker-compose.override.yml` for a development setup that mounts local sources
