defmodule EarthScanner.Trips.TripInstance do
  use Ecto.Schema
  import Ecto.Changeset

  alias EarthScanner.Trips.Trip

  schema "trip_instances" do
    field :date, :date
    field :available_tickets, :integer

    belongs_to :trip, Trip

    timestamps()
  end

  @required_fields ~w(date available_tickets trip_id)a

  def changeset(instance, attrs) do
    instance
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_number(:available_tickets, greater_than: 0)
  end
end
