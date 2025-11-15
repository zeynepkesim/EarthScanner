defmodule EarthScanner.Repo.Migrations.AddAdminIdToTrips do
  use Ecto.Migration

  def change do
    alter table(:trips) do
      add :admin_id, references(:users, on_delete: :delete_all), null: false
    end

    create index(:trips, [:admin_id])
  end
end
