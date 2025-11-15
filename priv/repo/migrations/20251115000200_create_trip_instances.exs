defmodule EarthScanner.Repo.Migrations.CreateTripInstances do
  use Ecto.Migration

  def change do
    create table(:trip_instances) do
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      add :date, :date, null: false
      add :available_tickets, :integer, null: false

      timestamps()
    end

    create index(:trip_instances, [:trip_id])
    create unique_index(:trip_instances, [:trip_id, :date])
  end
end
