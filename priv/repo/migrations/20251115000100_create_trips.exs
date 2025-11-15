defmodule EarthScanner.Repo.Migrations.CreateTrips do
  use Ecto.Migration

  def change do
    create table(:trips) do
      add :picture_url, :string
      # plane / bus / train
      add :transport_mode, :string, null: false
      add :source_city, :string, null: false
      add :destination_city, :string, null: false
      add :departure_time, :utc_datetime, null: false
      add :arrival_time, :utc_datetime, null: false
      add :duration_minutes, :integer, null: false
      add :price, :decimal, null: false
      add :co2_level, :integer, null: false
      add :available_tickets, :integer, null: false

      add :admin_id, references(:users, on_delete: :nothing), null: false

      timestamps()
    end

    create index(:trips, [:source_city])
    create index(:trips, [:destination_city])
    create index(:trips, [:departure_time])
    create index(:trips, [:admin_id])
  end
end
