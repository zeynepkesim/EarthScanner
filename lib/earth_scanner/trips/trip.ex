defmodule EarthScanner.Trips.Trip do
  use Ecto.Schema
  import Ecto.Changeset

  alias EarthScanner.Accounts.User
  alias EarthScanner.Trips.TripInstance

  # FR-29: Trip schema with all required fields
  schema "trips" do
    field :picture_url, :string
    field :transport_mode, :string
    field :source_city, :string
    field :destination_city, :string
    field :departure_time, :utc_datetime
    field :arrival_time, :utc_datetime
    # FR-29: Auto-computed
    field :duration_minutes, :integer
    field :price, :decimal
    field :co2_level, :integer

    field :recommended_price, :decimal

    field :available_tickets, :integer

    belongs_to :admin, User, foreign_key: :admin_id
    # FR-36: Recurring trip instances
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
    picture_url
  )a

  @optional_fields ~w(
    recommended_price
  )a

  # FR-29: Trip changeset with validations
  def changeset(trip, attrs) do
    trip
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:transport_mode, ["plane", "bus", "train"])
    |> validate_number(:available_tickets, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:co2_level, greater_than_or_equal_to: 0)
    # FR-29: Auto-compute duration
    |> compute_duration()
    |> compute_recommended_price()
    # FR-29: Validate times
    |> validate_arrival_after_departure()
  end

  # --------------------------------------------------------
  # FR-29: Automatically compute trip duration in minutes
  # --------------------------------------------------------
  defp compute_duration(changeset) do
    dep = get_field(changeset, :departure_time)
    arr = get_field(changeset, :arrival_time)

    if dep && arr do
      minutes = DateTime.diff(arr, dep, :minute)

      if minutes <= 0 do
        changeset
      else
        put_change(changeset, :duration_minutes, minutes)
      end
    else
      changeset
    end
  end

  # --------------------------------------------------------
  # 2) Automatically compute recommended price
  # Based on transport mode and CO2 level
  # --------------------------------------------------------
  defp compute_recommended_price(changeset) do
    mode = get_field(changeset, :transport_mode)
    co2 = get_field(changeset, :co2_level)

    if mode && co2 do
      factor =
        case mode do
          "plane" -> 0.15
          "train" -> 0.05
          "bus" -> 0.07
          # Invalid transport modes will be caught by validation
          _ -> 0.0
        end

      recommended =
        co2
        |> Kernel.*(factor)
        |> Decimal.from_float()

      put_change(changeset, :recommended_price, recommended)
    else
      changeset
    end
  end

  # --------------------------------------------------------
  # FR-29: Validate arrival time is after departure time
  # --------------------------------------------------------
  defp validate_arrival_after_departure(changeset) do
    dep = get_field(changeset, :departure_time)
    arr = get_field(changeset, :arrival_time)

    if dep && arr && DateTime.compare(arr, dep) != :gt do
      add_error(changeset, :arrival_time, "must be after departure time")
    else
      changeset
    end
  end
end
