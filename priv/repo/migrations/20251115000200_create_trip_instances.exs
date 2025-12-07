defmodule EarthScanner.Repo.Migrations.CreateTripInstances do
  use Ecto.Migration

  # FR-36: Create trip_instances table for recurring trip dates
  def change do
    create table(:trip_instances) do
      # FR-36: Link to parent trip (cascade delete when trip is deleted)
      add :trip_id, references(:trips, on_delete: :delete_all), null: false
      # FR-36: Specific date for this trip instance
      add :date, :date, null: false
      # FR-36: Independent ticket inventory per instance
      add :available_tickets, :integer, null: false

      timestamps()
    end

    create index(:trip_instances, [:trip_id])
    create unique_index(:trip_instances, [:trip_id, :date])
  end
end
