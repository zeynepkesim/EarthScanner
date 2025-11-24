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

    # 👉 NEW FIELD
    field :recommended_price, :decimal

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

  @optional_fields ~w(
    picture_url
    recommended_price
  )a

  def changeset(trip, attrs) do
    trip
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:transport_mode, ["plane", "bus", "train"])
    |> validate_number(:available_tickets, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
    |> validate_number(:co2_level, greater_than_or_equal_to: 0)
    |> compute_duration()
    |> compute_recommended_price()
    |> validate_arrival_after_departure()
  end

  # --------------------------------------------------------
  # 1) Automatically compute duration
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
  # 3) Validate arrival > departure
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
