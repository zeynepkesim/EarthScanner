defmodule EarthScanner.Repo.Migrations.AddNotificationDeliveryFields do
  use Ecto.Migration

  def change do
    alter table(:notifications) do
      add :status, :string, default: "pending"
      add :attempts, :integer, default: 0
      add :last_attempted_at, :utc_datetime
      add :error, :text
      add :delivered_at, :utc_datetime
    end

    create index(:notifications, [:status])
  end
end
