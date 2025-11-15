defmodule EarthScanner.Trips do
  @moduledoc "Trips context"

  import Ecto.Query, warn: false
  alias EarthScanner.Repo
  alias Ecto.Multi
  alias EarthScanner.Trips.{Trip, TripInstance}

  def list_future_trip_instances do
    today = Date.utc_today()

    from(ti in TripInstance,
      where: ti.date >= ^today,
      join: tr in assoc(ti, :trip),
      preload: [trip: tr]
    )
    |> Repo.all()
  end

  @doc """
  Creates a trip and optional instances.
  attrs expected keys:
    - "dates" => ["2025-11-14", ...] (optional)
    - other trip fields (departure_time, arrival_time, etc.)
  """
  def create_trip(attrs) when is_map(attrs) do
    dates = Map.get(attrs, "dates", [])

    multi =
      Multi.new()
      |> Multi.insert(:trip, Trip.changeset(%Trip{}, attrs))
      |> Multi.run(:instances, fn repo, %{trip: trip} ->
        Enum.reduce_while(dates, {:ok, []}, fn date_str, {:ok, acc} ->
          case Date.from_iso8601(date_str) do
            {:ok, date} ->
              changes = %{
                trip_id: trip.id,
                date: date,
                available_tickets: trip.available_tickets
              }

              case repo.insert(TripInstance.changeset(%TripInstance{}, changes)) do
                {:ok, inst} -> {:cont, {:ok, [inst | acc]}}
                {:error, cs} -> {:halt, {:error, cs}}
              end

            {:error, _} ->
              {:halt, {:error, "invalid_date: #{date_str}"}}
          end
        end)
      end)

    case Repo.transaction(multi) do
      {:ok, %{trip: trip, instances: {:ok, instances}}} -> {:ok, trip, Enum.reverse(instances)}
      {:ok, %{trip: trip}} -> {:ok, trip, []}
      {:error, _op, reason, _changes} -> {:error, reason}
    end
  end

  # helper: get single trip with its instances
  def get_trip_with_instances!(id) do
    Repo.get!(Trip, id) |> Repo.preload(:instances)
  end
end
