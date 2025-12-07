defmodule EarthScanner.Release do
  @moduledoc """
  Release tasks for running migrations in a release.

  Provides `migrate/0` which is invoked via `bin/earth_scanner eval "EarthScanner.Release.migrate"`.
  """

  @app :earth_scanner

  def migrate do
    IO.puts("Release: loading app...")
    # Load the application so repos and config are available
    :ok = Application.load(@app)

    IO.puts("Release: running migrations...")

    repos = Application.fetch_env!(@app, :ecto_repos)

    Enum.each(repos, fn repo ->
      run_migrations_for(repo)
    end)

    IO.puts("Release: migrations complete")
  end

  defp run_migrations_for(repo) do
    # Migrations are expected to live under priv/repo/migrations
    migrations_path = Application.app_dir(@app, "priv/repo/migrations")

    IO.puts("Running migrations for #{inspect(repo)} from #{migrations_path}")

    # Ensure the repo supervision is started so migrations can run
    {:ok, _pid} = repo.start_link(pool_size: 2)

    Ecto.Migrator.with_repo(repo, fn repo_mod ->
      Ecto.Migrator.run(repo_mod, migrations_path, :up, all: true)
    end)
  end
end
