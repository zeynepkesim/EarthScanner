defmodule EarthScanner.Purchases.Purchase do
  use Ecto.Schema
  import Ecto.Changeset

  alias EarthScanner.Accounts.User
  alias EarthScanner.Trips.TripInstance

  schema "purchases" do
    belongs_to :user, User
    belongs_to :trip_instance, TripInstance

    timestamps()
  end

  def changeset(purchase, attrs) do
    purchase
    |> cast(attrs, [:user_id, :trip_instance_id])
    |> validate_required([:user_id, :trip_instance_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:trip_instance_id)
    |> unique_constraint([:user_id, :trip_instance_id],
      name: :purchases_user_id_trip_instance_id_index
    )
  end
end
