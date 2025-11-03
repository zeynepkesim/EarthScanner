defmodule EarthScanner.Repo do
  use Ecto.Repo,
    otp_app: :earth_scanner,
    adapter: Ecto.Adapters.Postgres
end
