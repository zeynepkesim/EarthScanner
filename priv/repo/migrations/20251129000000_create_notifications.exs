defmodule EarthScanner.Repo.Migrations.CreateNotifications do
  use Ecto.Migration

  def change do
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :kind, :string, null: false
      add :payload, :map, null: false
      add :read_at, :utc_datetime

      timestamps()
    end

    create index(:notifications, [:user_id])
  end
end
