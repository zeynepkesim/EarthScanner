defmodule EarthScanner.Repo.Migrations.CreateSearchHistories do
  use Ecto.Migration

  def change do
    create table(:search_histories) do
      add :source_city, :string, null: false
      add :destination_city, :string, null: false
      # FR-06: Cascade delete search history when user is deleted
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(:search_histories, [:user_id])
    create index(:search_histories, [:user_id, :inserted_at])
  end
end
