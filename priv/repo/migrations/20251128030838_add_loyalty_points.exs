defmodule EarthScanner.Repo.Migrations.AddLoyaltyPoints do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :loyalty_points, :integer, default: 0, null: false
    end

    alter table(:purchases) do
      add :points_earned, :integer, default: 0, null: false
      add :points_redeemed, :integer, default: 0, null: false
    end
  end
end
