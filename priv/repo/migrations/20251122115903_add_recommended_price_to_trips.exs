defmodule EarthScanner.Repo.Migrations.AddRecommendedPriceToTrips do
  use Ecto.Migration

  def change do
    alter table(:trips) do
      add :recommended_price, :decimal
    end
  end
end
