defmodule EarthScanner.Trips.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  alias EarthScanner.Accounts.User
  alias EarthScanner.Trips.TripInstance

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

    belongs_to :admin, User, foreign_key: :admin_id
    has_many :instances, TripInstance
    has_many :purchases, through: [:instances, :purchases]

    timestamps()
  end

  @required_fields ~w(
    transport_mode
    source_city
    destination_city
    departure_time
    arrival_time
    price
    co2_level
    available_tickets
    admin_id
  )a

  @optional_fields ~w(picture_url)a

  def changeset(trip, attrs) do
    trip
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:transport_mode, ["plane", "bus", "train"])
    |> validate_number(:available_tickets, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:co2_level, greater_than_or_equal_to: 0)
    |> compute_duration()
    |> validate_arrival_after_departure()
  end

  # FR-29: Trip duration is calculated automatically
  defp compute_duration(changeset) do
    dep = get_field(changeset, :departure_time)
    arr = get_field(changeset, :arrival_time)

    if dep && arr do
      minutes = DateTime.diff(arr, dep, :minute)

      if minutes <= 0 do
        # arrival must be after departure
        changeset
      else
        put_change(changeset, :duration_minutes, minutes)
      end
    else
      changeset
    end
  end

  defp validate_arrival_after_departure(changeset) do
    dep = get_field(changeset, :departure_time)
    arr = get_field(changeset, :arrival_time)

    if dep && arr && DateTime.compare(arr, dep) != :gt do
      add_error(changeset, :arrival_time, "must be after departure time")
    else
      changeset
    end
  end

  # ---------- FR-10: Top trips (fastest, cheapest, greenest) ----------

  @doc """
  Computes top trips (fastest, cheapest, greenest) from the given list.

  Tie-breaking is deterministic:
    * Fastest  -> duration_minutes -> price -> id
    * Cheapest -> price -> duration_minutes -> id
    * Greenest -> co2_level -> price -> duration_minutes -> id
  """
  def compute_top_trips([]) do
    %{fastest: nil, cheapest: nil, greenest: nil}
  end

  def compute_top_trips(trips) when is_list(trips) do
    %{
      fastest: pick_fastest(trips),
      cheapest: pick_cheapest(trips),
      greenest: pick_greenest(trips)
    }
  end

  # Picks the fastest trip using duration as main metric.
  # Tie-breaking uses price and then id to keep the result deterministic.
  defp pick_fastest(trips) do
    Enum.min_by(trips, fn trip ->
      {
        trip.duration_minutes || 0,
        normalize_price(trip.price),
        trip.id || 0
      }
    end)
  end

  # Picks the cheapest trip using price as main metric.
  # Tie-breaking uses duration and then id.
  defp pick_cheapest(trips) do
    Enum.min_by(trips, fn trip ->
      {
        normalize_price(trip.price),
        trip.duration_minutes || 0,
        trip.id || 0
      }
    end)
  end

  # Picks the greenest trip using CO2 as main metric.
  # Tie-breaking uses price, then duration, then id.
  defp pick_greenest(trips) do
    Enum.min_by(trips, fn trip ->
      {
        trip.co2_level || 0,
        normalize_price(trip.price),
        trip.duration_minutes || 0,
        trip.id || 0
      }
    end)
  end

  # Normalizes different price representations to a float for comparison.
  defp normalize_price(%Decimal{} = price), do: Decimal.to_float(price)
  defp normalize_price(price) when is_integer(price), do: price * 1.0
  defp normalize_price(price) when is_float(price), do: price
  defp normalize_price(_), do: 0.0
end
