defmodule EarthScanner.Trips.TripInstance do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trip_instances" do
    field :date, :date
    field :available_tickets, :integer

    belongs_to :trip, EarthScanner.Trips.Trip

    timestamps()
  end

  @required ~w(date available_tickets trip_id)a

  def changeset(instance, attrs) do
    instance
    |> cast(attrs, [:date, :available_tickets, :trip_id])
    |> validate_required(@required)
  end
end
