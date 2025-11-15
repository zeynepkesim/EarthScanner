defmodule EarthScanner.Trips.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trips" do
    field :picture_url, :string
    field :transport_mode, :string
    field :source_city, :string
    field :destination_city, :string
    field :departure_time, :utc_datetime
    field :arrival_time, :utc_datetime
    field :duration_minutes, :integer
    field :price, :decimal
    field :co2_level, :integer
    field :available_tickets, :integer

    has_many :instances, EarthScanner.Trips.TripInstance, on_delete: :delete_all

    timestamps()
  end

  @required ~w(transport_mode source_city destination_city departure_time arrival_time price co2_level available_tickets)a

  def changeset(trip, attrs) do
    trip
    |> cast(attrs, [:picture_url, :transport_mode, :source_city, :destination_city, :departure_time, :arrival_time, :price, :co2_level, :available_tickets])
    |> validate_required(@required)
    |> compute_duration()
  end

  defp compute_duration(changeset) do
    with {:ok, dep} <- fetch_change(changeset, :departure_time) |> to_ok(),
         {:ok, arr} <- fetch_change(changeset, :arrival_time) |> to_ok() do
      minutes = DateTime.diff(arr, dep, :second) |> Kernel.div(60)
      put_change(changeset, :duration_minutes, minutes)
    else
      _ -> changeset
    end
  end

  defp to_ok(nil), do: :error
  defp to_ok({:ok, val}), do: {:ok, val}
end
