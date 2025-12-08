defmodule EarthScanner.Repo.Migrations.CreatePointLogs do
  use Ecto.Migration

  def change do
    create table(:point_logs) do
      # FR-06: Cascade delete point logs when user is deleted
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :change_amount, :integer, null: false
      add :reason, :string, null: false
      add :balance_after, :integer, null: false

      timestamps()
    end

    create index(:point_logs, [:user_id])
  end
end
