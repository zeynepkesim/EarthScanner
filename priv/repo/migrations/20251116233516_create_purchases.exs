defmodule EarthScanner.Repo.Migrations.CreatePurchases do
  use Ecto.Migration

  def change do
    create table(:purchases) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :trip_instance_id, references(:trip_instances, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:purchases, [:user_id])
    create index(:purchases, [:trip_instance_id])
    create unique_index(:purchases, [:user_id, :trip_instance_id])
  end
end
