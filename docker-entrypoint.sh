#!/bin/sh
set -e

echo "==> Entrypoint: waiting for database to become available..."

# Default values
: ${POSTGRES_HOST:=db}
: ${POSTGRES_PORT:=5432}
: ${POSTGRES_USER:=postgres}
: ${POSTGRES_DB:=earth_scanner_dev}

export PGPASSWORD=${POSTGRES_PASSWORD:-}

wait_for_db() {
  # wait until pg_isready reports the server is accepting connections
  until pg_isready -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$POSTGRES_USER" >/dev/null 2>&1; do
    echo "Waiting for postgres at ${POSTGRES_HOST}:${POSTGRES_PORT}..."
    sleep 1
  done
}

wait_for_db

echo "==> Running database migrations..."
/app/bin/earth_scanner eval "EarthScanner.Release.migrate"

echo "==> Starting the release..."
exec /app/bin/earth_scanner start
