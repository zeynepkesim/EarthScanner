defmodule EarthScanner.Trips.TripInstance do
  use Ecto.Schema
  import Ecto.Changeset

  alias EarthScanner.Trips.Trip

  schema "trip_instances" do
    field :date, :date
    field :available_tickets, :integer

    belongs_to :trip, Trip
    has_many :purchases, EarthScanner.Purchases.Purchase

    timestamps()
  end

  @required_fields ~w(date available_tickets trip_id)a

  # FR-36: TripInstance changeset with validations
  def changeset(instance, attrs) do
    instance
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:available_tickets, greater_than_or_equal_to: 0)
    |> unique_constraint([:trip_id, :date],
      name: :trip_instances_trip_id_date_index,
      message: "has already been taken"
    )
  end
end
